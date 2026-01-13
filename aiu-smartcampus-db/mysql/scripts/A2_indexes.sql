-- mysql/scripts/A2_indexes.sql
-- Part A2: Index creation (single-column + required composite + covering index)

USE aiu_urms_ext;

-- Helper pattern: drop index if exists (idempotent)
-- NOTE: MySQL doesn't support DROP INDEX IF EXISTS, so we use information_schema + dynamic SQL.

-- ==============
-- activity_logs
-- ==============

-- Single-column indexes on frequently searched fields
SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='activity_logs' AND index_name='idx_activity_type'
), 'DROP INDEX idx_activity_type ON activity_logs', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_activity_type ON activity_logs(activity_type);

SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='activity_logs' AND index_name='idx_activity_time'
), 'DROP INDEX idx_activity_time ON activity_logs', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_activity_time ON activity_logs(`timestamp`);

SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='activity_logs' AND index_name='idx_activity_ip'
), 'DROP INDEX idx_activity_ip ON activity_logs', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_activity_ip ON activity_logs(ip_address);

-- Required composite index (student_id, timestamp)
SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='activity_logs' AND index_name='idx_activity_student_time'
), 'DROP INDEX idx_activity_student_time ON activity_logs', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_activity_student_time ON activity_logs(student_id, `timestamp`);

-- Covering index for the reporting query (covers: student_id, timestamp, activity_type, session_duration)
SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='activity_logs' AND index_name='idx_activity_cover_report'
), 'DROP INDEX idx_activity_cover_report ON activity_logs', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_activity_cover_report ON activity_logs(student_id, `timestamp`, activity_type, session_duration);

-- =======
-- sensors
-- =======

-- Frequently filtered by sensor_type and room correlation
SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='sensors' AND index_name='idx_sensors_type'
), 'DROP INDEX idx_sensors_type ON sensors', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_sensors_type ON sensors(sensor_type);

SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='sensors' AND index_name='idx_sensors_room_type'
), 'DROP INDEX idx_sensors_room_type ON sensors', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_sensors_room_type ON sensors(room_id, sensor_type);

-- =============
-- sensor_readings
-- =============
-- Note: uq_sensor_readings(sensor_id, timestamp) already exists and is excellent for joins.
-- Add time/status indexes for global time-window + status filters.

SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='sensor_readings' AND index_name='idx_readings_time'
), 'DROP INDEX idx_readings_time ON sensor_readings', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_readings_time ON sensor_readings(`timestamp`);

SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='sensor_readings' AND index_name='idx_readings_status_time'
), 'DROP INDEX idx_readings_status_time ON sensor_readings', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_readings_status_time ON sensor_readings(status, `timestamp`);

-- ==========
-- materials
-- ==========
-- Frequent filters: course_id (already indexed by FK/uq), file_type, upload_date

SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='materials' AND index_name='idx_materials_type'
), 'DROP INDEX idx_materials_type ON materials', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_materials_type ON materials(file_type);

SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='materials' AND index_name='idx_materials_upload_date'
), 'DROP INDEX idx_materials_upload_date ON materials', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_materials_upload_date ON materials(upload_date);

-- =========
-- students
-- =========
-- Frequent filter for analytics dashboards (active/suspended/etc.)
SET @sql := (SELECT IF(EXISTS(
  SELECT 1 FROM information_schema.statistics
  WHERE table_schema=DATABASE() AND table_name='students' AND index_name='idx_students_status'
), 'DROP INDEX idx_students_status ON students', 'SELECT 1'));
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
CREATE INDEX idx_students_status ON students(status);
