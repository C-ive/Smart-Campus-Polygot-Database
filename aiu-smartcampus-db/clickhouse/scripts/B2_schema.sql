-- B2 (ClickHouse): Time-series storage + downsampling + retention
CREATE DATABASE IF NOT EXISTS aiu_timeseries;

CREATE TABLE IF NOT EXISTS aiu_timeseries.sensors_dim
(
  sensor_id UInt32,
  room_id   UInt32,
  sensor_type LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY sensor_id;

-- Raw time-series table
CREATE TABLE IF NOT EXISTS aiu_timeseries.sensor_readings_raw
(
  sensor_id UInt32,
  room_id   UInt32,
  sensor_type LowCardinality(String),
  ts DateTime64(3, 'UTC'),
  value Float64,
  status LowCardinality(String)
)
ENGINE = MergeTree
PARTITION BY toDate(ts)
ORDER BY (sensor_id, ts)
TTL toDateTime(ts) + INTERVAL 365 DAY DELETE;

-- Downsampled hourly aggregates using aggregate states (continuous via MV)
CREATE TABLE IF NOT EXISTS aiu_timeseries.sensor_readings_hourly
(
  sensor_id UInt32,
  room_id   UInt32,
  sensor_type LowCardinality(String),
  hour DateTime('UTC'),

  avg_state AggregateFunction(avg, Float64),
  min_state AggregateFunction(min, Float64),
  max_state AggregateFunction(max, Float64),
  cnt_state AggregateFunction(count, UInt64)
)
ENGINE = AggregatingMergeTree
PARTITION BY toDate(hour)
ORDER BY (sensor_id, sensor_type, hour);

CREATE MATERIALIZED VIEW IF NOT EXISTS aiu_timeseries.mv_sensor_readings_hourly
TO aiu_timeseries.sensor_readings_hourly
AS
SELECT
  sensor_id,
  room_id,
  sensor_type,
  toStartOfHour(ts) AS hour,
  avgState(value)   AS avg_state,
  minState(value)   AS min_state,
  maxState(value)   AS max_state,
  countState()      AS cnt_state
FROM aiu_timeseries.sensor_readings_raw
GROUP BY sensor_id, room_id, sensor_type, hour;

-- Proof marker (so B2_SCHEMA_RUN.txt isn't empty)
SELECT 'B2_SCHEMA_OK' AS status;
