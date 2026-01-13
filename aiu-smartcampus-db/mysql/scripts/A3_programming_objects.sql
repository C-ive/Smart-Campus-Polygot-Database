-- mysql/scripts/A3_programming_objects.sql
-- Part A (3): Stored Procedure + Trigger + User-Defined Function
-- Target: MySQL 8.0+

USE aiu_urms_ext;

-- Some MySQL setups require this to create non-deterministic functions safely
-- (safe for container/dev use)
SET GLOBAL log_bin_trust_function_creators = 1;

-- =========================================================
-- 1) Archive Table for old activity logs (older than 1 year)
-- =========================================================
CREATE TABLE IF NOT EXISTS activity_logs_archive (
  id BIGINT UNSIGNED NOT NULL,
  student_id INT UNSIGNED NOT NULL,
  activity_type VARCHAR(30) NOT NULL,
  resource_id BIGINT UNSIGNED NULL,
  `timestamp` DATETIME(3) NOT NULL,
  session_duration INT UNSIGNED NOT NULL DEFAULT 0,
  ip_address VARCHAR(45) NOT NULL,
  archived_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (id),

  -- Helpful indexes for archive queries
  KEY idx_archive_student_time (student_id, `timestamp`),
  KEY idx_archive_time (`timestamp`),

  -- Keep validation consistent with live table
  CONSTRAINT chk_archive_activity_type CHECK (
    activity_type IN (
      'login','logout','view_material','download_material',
      'watch_video','attempt_quiz','submit_assignment',
      'forum_post','message'
    )
  ),
  CONSTRAINT chk_archive_session_duration CHECK (session_duration >= 0),
  CONSTRAINT chk_archive_ip_not_empty CHECK (CHAR_LENGTH(ip_address) >= 7)
) ENGINE=InnoDB;

-- ==========================================
-- 2) UDF: Calculate student engagement score
-- ==========================================
DROP FUNCTION IF EXISTS udf_CalculateStudentEngagement;

DELIMITER $$
CREATE FUNCTION udf_CalculateStudentEngagement(
  p_student_id INT UNSIGNED,
  p_days INT UNSIGNED
)
RETURNS DECIMAL(6,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_days INT UNSIGNED DEFAULT 30;
  DECLARE v_count BIGINT UNSIGNED DEFAULT 0;
  DECLARE v_seconds BIGINT UNSIGNED DEFAULT 0;

  DECLARE v_freq_per_day DECIMAL(10,4) DEFAULT 0;
  DECLARE v_minutes_per_day DECIMAL(10,4) DEFAULT 0;
  DECLARE v_score DECIMAL(10,4) DEFAULT 0;

  -- Guard rails
  IF p_days IS NOT NULL AND p_days > 0 AND p_days <= 3650 THEN
    SET v_days = p_days;
  END IF;

  SELECT COUNT(*), COALESCE(SUM(session_duration),0)
    INTO v_count, v_seconds
  FROM activity_logs
  WHERE student_id = p_student_id
    AND `timestamp` >= (NOW() - INTERVAL v_days DAY);

  SET v_freq_per_day    = v_count / v_days;
  SET v_minutes_per_day = (v_seconds / 60) / v_days;

  -- Score formula (0..100):
  -- - Frequency: up to 60 points (>= 6 actions/day -> 60)
  -- - Duration : up to 40 points (>= 20 minutes/day -> 40)
  SET v_score =
      LEAST(60, v_freq_per_day * 10)
    + LEAST(40, v_minutes_per_day * 2);

  RETURN ROUND(v_score, 2);
END$$
DELIMITER ;

-- ==========================================
-- 3) Stored Procedure: Student Analytics
-- ==========================================
DROP PROCEDURE IF EXISTS sp_StudentAnalytics;

DELIMITER $$
CREATE PROCEDURE sp_StudentAnalytics(IN p_student_id INT UNSIGNED)
BEGIN
  /*
    Returns:
    - Basic student info
    - Number of courses enrolled
    - Total activity time from logs
    - Average performance across courses
    (Plus: engagement_score_30d as a helpful extra metric)
  */

  SELECT
    s.student_id,
    s.reg_no,
    s.first_name,
    s.last_name,
    s.email,
    d.name AS department_name,
    s.status,

    COALESCE(en.course_count, 0) AS courses_enrolled,

    COALESCE(act.total_actions, 0)  AS total_activity_actions,
    COALESCE(act.total_seconds, 0)  AS total_activity_seconds,
    ROUND(COALESCE(act.total_seconds,0) / 60, 2)    AS total_activity_minutes,
    ROUND(COALESCE(act.total_seconds,0) / 3600, 2)  AS total_activity_hours,
    act.last_activity_at,

    perf.avg_final_score AS avg_final_score,

    udf_CalculateStudentEngagement(p_student_id, 30) AS engagement_score_30d

  FROM students s
  JOIN departments d
    ON d.department_id = s.department_id

  LEFT JOIN (
    SELECT student_id, COUNT(DISTINCT course_id) AS course_count
    FROM enrollments
    WHERE student_id = p_student_id
      AND status IN ('enrolled','completed')
    GROUP BY student_id
  ) en
    ON en.student_id = s.student_id

  LEFT JOIN (
    SELECT student_id,
           COUNT(*) AS total_actions,
           COALESCE(SUM(session_duration),0) AS total_seconds,
           MAX(`timestamp`) AS last_activity_at
    FROM activity_logs
    WHERE student_id = p_student_id
    GROUP BY student_id
  ) act
    ON act.student_id = s.student_id

  LEFT JOIN (
    SELECT student_id, ROUND(AVG(final_score),2) AS avg_final_score
    FROM student_course_performance
    WHERE student_id = p_student_id
    GROUP BY student_id
  ) perf
    ON perf.student_id = s.student_id

  WHERE s.student_id = p_student_id;
END$$
DELIMITER ;

-- ==========================================
-- 4) Trigger: Archive old activity logs on delete
-- ==========================================
DROP TRIGGER IF EXISTS trg_archive_activity;

DELIMITER $$
CREATE TRIGGER trg_archive_activity
BEFORE DELETE ON activity_logs
FOR EACH ROW
BEGIN
  IF OLD.`timestamp` < (NOW() - INTERVAL 1 YEAR) THEN
    INSERT INTO activity_logs_archive
      (id, student_id, activity_type, resource_id, `timestamp`, session_duration, ip_address, archived_at)
    VALUES
      (OLD.id, OLD.student_id, OLD.activity_type, OLD.resource_id, OLD.`timestamp`, OLD.session_duration, OLD.ip_address, NOW());
  END IF;
END$$
DELIMITER ;
