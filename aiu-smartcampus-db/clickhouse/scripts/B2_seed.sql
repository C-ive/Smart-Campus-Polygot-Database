INSERT INTO aiu_timeseries.sensor_readings_raw (sensor_id, room_id, sensor_type, ts, value, status) VALUES
(1, 101, 'temperature', now64(3) - INTERVAL 2 HOUR, 22.5, 'OK'),
(1, 101, 'temperature', now64(3) - INTERVAL 1 HOUR, 23.1, 'OK'),
(2, 101, 'occupancy',   now64(3) - INTERVAL 2 HOUR, 10,   'OK'),
(2, 101, 'occupancy',   now64(3) - INTERVAL 1 HOUR, 18,   'OK');

-- Proof queries (so B2_SEED_RUN.txt isn't empty)
SELECT count() AS raw_rows FROM aiu_timeseries.sensor_readings_raw;
SELECT count() AS hourly_rows FROM aiu_timeseries.sensor_readings_hourly;
