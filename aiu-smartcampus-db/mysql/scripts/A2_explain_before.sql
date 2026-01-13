-- mysql/scripts/A2_explain_before.sql
-- A2: EXPLAIN ANALYZE (before adding A2 indexes)

USE aiu_urms_ext;

-- Pick a real student_id and room_id from current data
SET @sid := (SELECT student_id FROM students ORDER BY student_id LIMIT 1);
SET @rid := (SELECT room_id FROM rooms ORDER BY room_id LIMIT 1);

-- Q1) Student activity pattern analysis (last 30 days)
PREPARE q1 FROM '
EXPLAIN ANALYZE FORMAT=TREE
SELECT al.student_id, al.activity_type,
       COUNT(*) AS actions,
       SUM(al.session_duration) AS total_seconds,
       MIN(al.`timestamp`) AS first_seen,
       MAX(al.`timestamp`) AS last_seen
FROM activity_logs al
WHERE al.student_id = ? AND al.`timestamp` >= NOW() - INTERVAL 30 DAY
GROUP BY al.student_id, al.activity_type
ORDER BY total_seconds DESC
';
EXECUTE q1 USING @sid;
DEALLOCATE PREPARE q1;

-- Q2) Sensor data correlation (temperature vs occupancy, same room, last 7 days)
PREPARE q2 FROM '
EXPLAIN ANALYZE FORMAT=TREE
SELECT r1.`timestamp`,
       r1.value AS temperature,
       r2.value AS occupancy
FROM sensors s_temp
JOIN sensor_readings r1
  ON r1.sensor_id = s_temp.sensor_id
JOIN sensors s_occ
  ON s_occ.room_id = s_temp.room_id
 AND s_occ.sensor_type = ''occupancy''
JOIN sensor_readings r2
  ON r2.sensor_id = s_occ.sensor_id
 AND r2.`timestamp` = r1.`timestamp`
WHERE s_temp.room_id = ?
  AND s_temp.sensor_type = ''temperature''
  AND r1.`timestamp` BETWEEN NOW() - INTERVAL 7 DAY AND NOW()
ORDER BY r1.`timestamp`
';
EXECUTE q2 USING @rid;
DEALLOCATE PREPARE q2;

-- Q3) Cross-table analytics (risk-style: low scores OR low activity)
PREPARE q3 FROM '
EXPLAIN ANALYZE FORMAT=TREE
SELECT s.student_id, s.reg_no,
       AVG(scp.final_score) AS avg_score,
       COALESCE(SUM(al.session_duration),0) AS total_activity_seconds,
       COUNT(DISTINCT e.course_id) AS courses_enrolled
FROM students s
JOIN enrollments e
  ON e.student_id = s.student_id
LEFT JOIN student_course_performance scp
  ON scp.student_id = s.student_id AND scp.course_id = e.course_id
LEFT JOIN activity_logs al
  ON al.student_id = s.student_id
 AND al.`timestamp` >= NOW() - INTERVAL 90 DAY
WHERE s.status = ''active''
GROUP BY s.student_id, s.reg_no
HAVING avg_score < 60 OR total_activity_seconds < 1800
ORDER BY avg_score ASC, total_activity_seconds ASC
LIMIT 20
';
EXECUTE q3;
DEALLOCATE PREPARE q3;
