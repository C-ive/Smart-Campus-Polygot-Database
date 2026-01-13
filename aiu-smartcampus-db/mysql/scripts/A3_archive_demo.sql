-- mysql/scripts/A3_archive_demo.sql
USE aiu_urms_ext;

SET @sid := (SELECT student_id FROM students ORDER BY student_id LIMIT 1);

INSERT INTO activity_logs(student_id, activity_type, resource_id, `timestamp`, session_duration, ip_address)
VALUES
(@sid,'login', 1, NOW() - INTERVAL 400 DAY, 120, '192.168.1.10'),
(@sid,'view_material', 2, NOW() - INTERVAL 401 DAY, 300, '192.168.1.11'),
(@sid,'logout', 3, NOW() - INTERVAL 402 DAY, 60,  '192.168.1.12');

SELECT
  (SELECT COUNT(*) FROM activity_logs WHERE `timestamp` < NOW() - INTERVAL 1 YEAR) AS old_in_live_before,
  (SELECT COUNT(*) FROM activity_logs_archive) AS archived_before;

DELETE FROM activity_logs
WHERE `timestamp` < NOW() - INTERVAL 1 YEAR;

SELECT
  (SELECT COUNT(*) FROM activity_logs WHERE `timestamp` < NOW() - INTERVAL 1 YEAR) AS old_in_live_after,
  (SELECT COUNT(*) FROM activity_logs_archive) AS archived_after;

SELECT id, student_id, activity_type, `timestamp`, archived_at
FROM activity_logs_archive
ORDER BY archived_at DESC
LIMIT 10;
