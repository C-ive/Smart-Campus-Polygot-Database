#!/usr/bin/env python3
"""
B2_ingest.py — ClickHouse time-series ingestion (minute-level -> hourly MV)

What it does
- Ensures aiu_timeseries.sensors_dim is populated (occupancy, temperature, humidity, energy)
- Inserts minute-level readings into aiu_timeseries.sensor_readings_raw
- The materialized view mv_sensor_readings_hourly auto-populates aiu_timeseries.sensor_readings_hourly
- Supports --reset to TRUNCATE raw + hourly tables

Run (recommended)
docker run --rm --network aiu-smartcampus-db_default -v ${PWD}:/work -w /work --env-file .env python:3.12-slim `
  bash -lc "pip -q install clickhouse-connect && python clickhouse/scripts/B2_ingest.py --reset --hours 6"
"""

import argparse
import logging
import os
import random
import sys
from datetime import datetime, timedelta, timezone

import clickhouse_connect


def env(name: str, default: str = "") -> str:
    v = os.environ.get(name)
    return v if v is not None and v != "" else default


def get_client():
    # Inside the docker network, ClickHouse is reachable by service name "clickhouse"
    host = env("CLICKHOUSE_HOST", "clickhouse")
    port = int(env("CLICKHOUSE_PORT", "8123"))
    user = env("CLICKHOUSE_USER", env("CH_USER", "ch_admin"))
    password = env("CLICKHOUSE_PASSWORD", env("CH_PASSWORD", "chpass123"))
    database = env("CLICKHOUSE_DB", "aiu_timeseries")

    return clickhouse_connect.get_client(
        host=host,
        port=port,
        username=user,
        password=password,
        database=database,
        secure=False,
    )


def scalar(client, query: str):
    res = client.query(query)
    if res.result_rows and res.result_rows[0]:
        return res.result_rows[0][0]
    return None


def ensure_sensors_dim(client, logger):
    # If empty, seed a small but realistic sensor fleet
    n = scalar(client, "SELECT count() FROM aiu_timeseries.sensors_dim")
    if n is None:
        n = 0

    if int(n) == 0:
        logger.info("sensors_dim empty -> inserting seed sensors")
        sensors = [
            # room 101
            (1, 101, "occupancy"),
            (2, 101, "temperature"),
            (3, 101, "humidity"),
            (4, 101, "energy"),
            # room 102
            (5, 102, "occupancy"),
            (6, 102, "temperature"),
            (7, 102, "humidity"),
            (8, 102, "energy"),
        ]
        client.insert(
            "aiu_timeseries.sensors_dim",
            sensors,
            column_names=["sensor_id", "room_id", "sensor_type"],
        )

    rows = client.query(
        "SELECT sensor_id, room_id, sensor_type FROM aiu_timeseries.sensors_dim ORDER BY sensor_id"
    ).result_rows
    logger.info("Loaded %d sensors from sensors_dim", len(rows))
    return rows


def gen_value(sensor_type: str, t: datetime) -> tuple[float, str]:
    """
    Returns (value, status)
    status: ok | warn
    """
    minute = t.minute
    hour = t.hour

    # small daily-ish patterns + noise
    if sensor_type == "occupancy":
        # busier during working hours
        base = 5 if hour < 8 or hour > 18 else 25
        wave = 8 * (1 if 10 <= hour <= 16 else 0.5)
        val = base + wave + random.gauss(0, 3)
        # occasional spike anomaly
        if random.random() < 0.01:
            val = max(val, 80 + random.random() * 20)
            return float(val), "warn"
        return float(max(val, 0)), "ok"

    if sensor_type == "temperature":
        base = 22.0 + (2.0 if 12 <= hour <= 16 else 0.0)
        val = base + random.gauss(0, 0.6)
        if random.random() < 0.005:
            val = base + 6 + random.random() * 3
            return float(val), "warn"
        return float(val), "ok"

    if sensor_type == "humidity":
        base = 55.0 + (5.0 if hour <= 7 else 0.0)
        val = base + random.gauss(0, 2.0)
        if random.random() < 0.005:
            val = base - 20 - random.random() * 10
            return float(val), "warn"
        return float(val), "ok"

    if sensor_type == "energy":
        # kWh per minute-ish proxy (scaled), with slight periodicity
        base = 1.0 if hour < 8 or hour > 18 else 3.5
        val = base + (0.2 * (minute % 10)) + random.gauss(0, 0.3)
        if random.random() < 0.005:
            val = base + 6 + random.random() * 3
            return float(val), "warn"
        return float(max(val, 0)), "ok"

    # fallback
    return float(random.random()), "ok"


def ingest(client, sensors, hours: int, logger):
    now = datetime.now(timezone.utc).replace(microsecond=0)
    start = now - timedelta(hours=hours)

    logger.info("Generating readings from %s to %s (UTC)", start.isoformat(), now.isoformat())

    rows = []
    ts = start
    total = 0

    while ts <= now:
        # DateTime64(3) supports ms; clickhouse-connect accepts datetime
        for sensor_id, room_id, sensor_type in sensors:
            v, status = gen_value(sensor_type, ts)
            rows.append((int(sensor_id), int(room_id), str(sensor_type), ts, float(v), str(status)))

        if len(rows) >= 5000:
            client.insert(
                "aiu_timeseries.sensor_readings_raw",
                rows,
                column_names=["sensor_id", "room_id", "sensor_type", "ts", "value", "status"],
            )
            total += len(rows)
            rows.clear()

        ts += timedelta(minutes=1)

    if rows:
        client.insert(
            "aiu_timeseries.sensor_readings_raw",
            rows,
            column_names=["sensor_id", "room_id", "sensor_type", "ts", "value", "status"],
        )
        total += len(rows)

    logger.info("Inserted %d rows into sensor_readings_raw", total)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=int, default=6)
    ap.add_argument("--reset", action="store_true")
    args = ap.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
    )
    logger = logging.getLogger("B2_ingest")

    try:
        client = get_client()
        logger.info(
            "Connecting to ClickHouse http://%s:%s as %s",
            env("CLICKHOUSE_HOST", "clickhouse"),
            env("CLICKHOUSE_PORT", "8123"),
            env("CLICKHOUSE_USER", "ch_admin"),
        )

        if args.reset:
            logger.info("Reset requested: TRUNCATE raw + hourly tables")
            client.command("TRUNCATE TABLE IF EXISTS aiu_timeseries.sensor_readings_raw")
            client.command("TRUNCATE TABLE IF EXISTS aiu_timeseries.sensor_readings_hourly")

        sensors = ensure_sensors_dim(client, logger)
        ingest(client, sensors, args.hours, logger)

        c = scalar(client, "SELECT count() FROM aiu_timeseries.sensor_readings_raw")
        mn = scalar(client, "SELECT min(ts) FROM aiu_timeseries.sensor_readings_raw")
        mx = scalar(client, "SELECT max(ts) FROM aiu_timeseries.sensor_readings_raw")
        logger.info("Post-load raw_rows=%s min_ts=%s max_ts=%s", c, mn, mx)

    except Exception as e:
        logger.exception("Ingestion failed: %s", e)
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
