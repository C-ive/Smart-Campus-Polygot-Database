-- mysql/scripts/A2_seed_data.sql
-- Seed data for Part A2 (enough rows for meaningful EXPLAIN ANALYZE)

USE aiu_urms_ext;

-- ---------- Departments ----------
INSERT INTO departments(name)
SELECT 'Computing' WHERE NOT EXISTS (SELECT 1 FROM departments WHERE name='Computing');
INSERT INTO departments(name)
SELECT 'Business' WHERE NOT EXISTS (SELECT 1 FROM departments WHERE name='Business');
INSERT INTO departments(name)
SELECT 'Theology' WHERE NOT EXISTS (SELECT 1 FROM departments WHERE name='Theology');

-- ---------- Rooms ----------
INSERT INTO rooms(room_code, building, capacity)
SELECT 'B1-101','Block B',60 WHERE NOT EXISTS (SELECT 1 FROM rooms WHERE room_code='B1-101');
INSERT INTO rooms(room_code, building, capacity)
SELECT 'B1-102','Block B',45 WHERE NOT EXISTS (SELECT 1 FROM rooms WHERE room_code='B1-102');
INSERT INTO rooms(room_code, building, capacity)
SELECT 'A2-201','Block A',80 WHERE NOT EXISTS (SELECT 1 FROM rooms WHERE room_code='A2-201');
INSERT INTO rooms(room_code, building, capacity)
SELECT 'A2-202','Block A',35 WHERE NOT EXISTS (SELECT 1 FROM rooms WHERE room_code='A2-202');
INSERT INTO rooms(room_code, building, capacity)
SELECT 'LIB-01','Library',120 WHERE NOT EXISTS (SELECT 1 FROM rooms WHERE room_code='LIB-01');

-- ---------- Lecturers ----------
INSERT IGNORE INTO lecturers(department_id, first_name, last_name, email)
SELECT d.department_id, 'John','Odhiambo','john.odhiambo@aiu.ac.ke' FROM departments d WHERE d.name='Computing';
INSERT IGNORE INTO lecturers(department_id, first_name, last_name, email)
SELECT d.department_id, 'Mary','Wanjiru','mary.wanjiru@aiu.ac.ke' FROM departments d WHERE d.name='Business';
INSERT IGNORE INTO lecturers(department_id, first_name, last_name, email)
SELECT d.department_id, 'Peter','Mutiso','peter.mutiso@aiu.ac.ke' FROM departments d WHERE d.name='Theology';

-- ---------- Courses (30) ----------
-- Generate 30 courses once (ignore duplicates by unique course_code)
INSERT IGNORE INTO courses(department_id, lecturer_id, course_code, course_name, credits)
SELECT
  d.department_id,
  (SELECT lecturer_id FROM lecturers l WHERE l.department_id=d.department_id ORDER BY l.lecturer_id LIMIT 1) AS lecturer_id,
  CONCAT('AIU', LPAD(n.n,3,'0')) AS course_code,
  CONCAT('Course ', n.n) AS course_name,
  3 AS credits
FROM (
  SELECT 1 n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
  UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
  UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
  UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20
  UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL SELECT 24 UNION ALL SELECT 25
  UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL SELECT 28 UNION ALL SELECT 29 UNION ALL SELECT 30
) n
JOIN departments d ON d.name IN ('Computing','Business','Theology')
WHERE MOD(n.n,3)=
  CASE d.name WHEN 'Computing' THEN 1 WHEN 'Business' THEN 2 ELSE 0 END;

-- ---------- Students (200) ----------
-- Use INSERT IGNORE because reg_no and email are UNIQUE
INSERT IGNORE INTO students(department_id, reg_no, first_name, last_name, email, enrollment_year, status)
SELECT
  d.department_id,
  CONCAT('AIU2026-', LPAD(n.num,4,'0')) AS reg_no,
  CONCAT('Student', n.num) AS first_name,
  'Test' AS last_name,
  CONCAT('student', n.num, '@aiu.ac.ke') AS email,
  2026 AS enrollment_year,
  'active' AS status
FROM (
  SELECT (a.n + b.n*10 + c.n*100) + 1 AS num
  FROM (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
  CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
  CROSS JOIN (SELECT 0 n UNION ALL SELECT 1) c
) n
JOIN departments d
WHERE n.num <= 200
  AND MOD(n.num,3)=
    CASE d.name WHEN 'Computing' THEN 1 WHEN 'Business' THEN 2 ELSE 0 END;

-- ---------- Enrollments (each student into 4 courses) ----------
-- Uses PK(student_id, course_id) so INSERT IGNORE is safe.
INSERT IGNORE INTO enrollments(student_id, course_id, status)
SELECT
  s.student_id,
  c.course_id,
  'enrolled' AS status
FROM students s
JOIN (
  SELECT course_id,
         ROW_NUMBER() OVER (ORDER BY course_id) AS rn
  FROM courses
) c
ON c.rn IN (1,2,3,4) OR c.rn IN (5,6,7,8) OR c.rn IN (9,10,11,12) OR c.rn IN (13,14,15,16)
WHERE MOD(s.student_id,4)=MOD(c.rn,4);

-- ---------- Performance (for enrolled courses) ----------
INSERT IGNORE INTO student_course_performance(student_id, course_id, continuous_assessment, exam_score, grade_letter)
SELECT
  e.student_id,
  e.course_id,
  ROUND(40 + MOD(e.student_id*3 + e.course_id, 31), 2) AS ca,
  ROUND(30 + MOD(e.student_id*7 + e.course_id, 41), 2) AS exam,
  NULL AS grade_letter
FROM enrollments e;

-- ---------- Materials (2 per course) ----------
INSERT IGNORE INTO materials(course_id, file_name, file_type, upload_date, file_path, file_size)
SELECT
  c.course_id,
  CONCAT(c.course_code,'-Week1.pdf') AS file_name,
  'pdf' AS file_type,
  NOW() - INTERVAL 14 DAY AS upload_date,
  CONCAT('/files/', c.course_code, '/week1.pdf') AS file_path,
  1200000 AS file_size
FROM courses c;

INSERT IGNORE INTO materials(course_id, file_name, file_type, upload_date, file_path, file_size)
SELECT
  c.course_id,
  CONCAT(c.course_code,'-Slides.pptx') AS file_name,
  'pptx' AS file_type,
  NOW() - INTERVAL 7 DAY AS upload_date,
  CONCAT('/files/', c.course_code, '/slides.pptx') AS file_path,
  3400000 AS file_size
FROM courses c;

-- ---------- Sensors (per room: temperature + occupancy + humidity + energy) ----------
-- FK index on room_id exists; we’ll add (room_id, sensor_type) in A2 indexes
INSERT IGNORE INTO sensors(room_id, sensor_type, manufacturer, installation_date)
SELECT r.room_id, 'temperature', 'AcmeSensors', CURDATE() - INTERVAL 120 DAY FROM rooms r;
INSERT IGNORE INTO sensors(room_id, sensor_type, manufacturer, installation_date)
SELECT r.room_id, 'occupancy', 'AcmeSensors', CURDATE() - INTERVAL 120 DAY FROM rooms r;
INSERT IGNORE INTO sensors(room_id, sensor_type, manufacturer, installation_date)
SELECT r.room_id, 'humidity', 'AcmeSensors', CURDATE() - INTERVAL 120 DAY FROM rooms r;
INSERT IGNORE INTO sensors(room_id, sensor_type, manufacturer, installation_date)
SELECT r.room_id, 'energy', 'AcmeSensors', CURDATE() - INTERVAL 120 DAY FROM rooms r;

-- ---------- Sensor readings (7 days hourly per sensor ~ few thousand rows) ----------
-- Generate hours 0..167 using digits cross join (168 hours)
INSERT IGNORE INTO sensor_readings(sensor_id, value, `timestamp`, status)
SELECT
  s.sensor_id,
  CASE s.sensor_type
    WHEN 'temperature' THEN ROUND(18 + (MOD(h.h,10) * 0.7), 2)
    WHEN 'humidity'    THEN ROUND(45 + (MOD(h.h,20) * 0.5), 2)
    WHEN 'occupancy'   THEN ROUND(MOD(h.h*3 + s.room_id, 60), 0)
    WHEN 'energy'      THEN ROUND(2 + (MOD(h.h,12) * 0.3), 2)
    ELSE 0
  END AS value,
  (NOW() - INTERVAL 7 DAY) + INTERVAL h.h HOUR AS ts,
  'OK' AS status
FROM sensors s
CROSS JOIN (
  SELECT (a.n + b.n*10 + c.n*100) AS h
  FROM (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
  CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
  CROSS JOIN (SELECT 0 n UNION ALL SELECT 1) c
) h
WHERE h.h BETWEEN 0 AND 167;

-- ---------- Activity logs (10,000 rows across last 90 days) ----------
INSERT IGNORE INTO activity_logs(student_id, activity_type, resource_id, `timestamp`, session_duration, ip_address)
SELECT
  1 + MOD(n.n, (SELECT COUNT(*) FROM students)) AS student_id,
  CASE MOD(n.n,9)
    WHEN 0 THEN 'login'
    WHEN 1 THEN 'view_material'
    WHEN 2 THEN 'download_material'
    WHEN 3 THEN 'watch_video'
    WHEN 4 THEN 'attempt_quiz'
    WHEN 5 THEN 'submit_assignment'
    WHEN 6 THEN 'forum_post'
    WHEN 7 THEN 'message'
    ELSE 'logout'
  END AS activity_type,
  MOD(n.n, 2000) AS resource_id,
  NOW() - INTERVAL MOD(n.n, 90) DAY - INTERVAL MOD(n.n*37, 86400) SECOND AS ts,
  30 + MOD(n.n*7, 1200) AS session_duration,
  CONCAT('192.168.', MOD(n.n,255), '.', MOD(n.n*3,255)) AS ip_address
FROM (
  SELECT (a.n + b.n*10 + c.n*100 + d.n*1000) + 1 AS n
  FROM (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
  CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
  CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
  CROSS JOIN (SELECT 0 n UNION ALL SELECT 1) d
) n
WHERE n.n BETWEEN 1 AND 10000;
