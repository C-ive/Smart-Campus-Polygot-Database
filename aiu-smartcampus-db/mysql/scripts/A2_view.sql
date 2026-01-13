-- mysql/scripts/A2_view.sql
-- Part A2: View combining student info with aggregate activity data

USE aiu_urms_ext;

DROP VIEW IF EXISTS vw_student_activity_agg;

CREATE VIEW vw_student_activity_agg AS
SELECT
  s.student_id,
  s.reg_no,
  s.first_name,
  s.last_name,
  d.name AS department_name,
  s.status,
  COALESCE(a.total_actions, 0) AS total_actions,
  COALESCE(a.total_activity_seconds, 0) AS total_activity_seconds,
  a.last_activity_at
FROM students s
JOIN departments d
  ON d.department_id = s.department_id
LEFT JOIN (
  SELECT
    student_id,
    COUNT(*) AS total_actions,
    SUM(session_duration) AS total_activity_seconds,
    MAX(`timestamp`) AS last_activity_at
  FROM activity_logs
  GROUP BY student_id
) a
  ON a.student_id = s.student_id;
