-- B2: Query proofs (Downsampling + Retention + Anomaly detection)

-- 0) Sanity proof: raw counts + time range
SELECT
  count() AS raw_rows,
  min(ts) AS min_ts,
  max(ts) AS max_ts
FROM aiu_timeseries.sensor_readings_raw;

-- 1) Downsampling proof: hourly aggregates (from MV/AggregatingMergeTree)
SELECT
  sensor_type,
  hour,
  avgMerge(avg_state)   AS avg_val,
  minMerge(min_state)   AS min_val,
  maxMerge(max_state)   AS max_val,
  countMerge(cnt_state) AS n
FROM aiu_timeseries.sensor_readings_hourly
GROUP BY sensor_type, hour
ORDER BY hour DESC, sensor_type
LIMIT 48;

-- 2) Retention proof: SHOW CREATE (must include TTL)
SHOW CREATE TABLE aiu_timeseries.sensor_readings_raw;

-- 3) Anomaly detection: values outside mean ± 2*stddev over last 6 hours
WITH
  now64(3, 'UTC') AS t0,
  stats AS
  (
    SELECT
      sensor_id,
      sensor_type,
      avg(value)       AS mu,
      stddevPop(value) AS sigma
    FROM aiu_timeseries.sensor_readings_raw
    WHERE ts >= (t0 - INTERVAL 6 HOUR)
    GROUP BY sensor_id, sensor_type
  )
SELECT
  r.sensor_id,
  r.room_id,
  r.sensor_type,
  r.ts,
  r.value,
  s.mu,
  s.sigma,
  (r.value - s.mu) / nullIf(s.sigma, 0) AS z
FROM aiu_timeseries.sensor_readings_raw AS r
INNER JOIN stats AS s USING (sensor_id, sensor_type)
WHERE s.sigma > 0
  AND abs(r.value - s.mu) > (2 * s.sigma)
ORDER BY abs(z) DESC, r.ts DESC
LIMIT 50;
