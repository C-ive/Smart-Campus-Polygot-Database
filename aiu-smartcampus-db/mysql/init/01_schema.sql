-- mysql/init/01_schema.sql
-- AIU Smart Campus: URMS Extension (BCNF-focused)
-- Target: MySQL 8.0+ (CHECK constraints enforced)

USE aiu_urms_ext;

-- Idempotent rebuild (safe for re-runs in dev)
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS sensor_readings;
DROP TABLE IF EXISTS sensors;
DROP TABLE IF EXISTS activity_logs;
DROP TABLE IF EXISTS materials;

DROP TABLE IF EXISTS student_course_performance;
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS lecturers;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS departments;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================
-- Core URMS tables (BCNF)
-- =========================

CREATE TABLE departments (
  department_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  CONSTRAINT uq_departments_name UNIQUE (name)
) ENGINE=InnoDB;

CREATE TABLE rooms (
  room_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  room_code VARCHAR(20) NOT NULL,
  building VARCHAR(100) NOT NULL,
  capacity INT UNSIGNED NOT NULL,
  CONSTRAINT uq_rooms_code UNIQUE (room_code),
  CONSTRAINT chk_rooms_capacity CHECK (capacity > 0)
) ENGINE=InnoDB;

CREATE TABLE lecturers (
  lecturer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  department_id INT UNSIGNED NOT NULL,
  first_name VARCHAR(60) NOT NULL,
  last_name VARCHAR(60) NOT NULL,
  email VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_lecturers_email UNIQUE (email),
  CONSTRAINT fk_lecturers_department FOREIGN KEY (department_id)
    REFERENCES departments(department_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE students (
  student_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  department_id INT UNSIGNED NOT NULL,
  reg_no VARCHAR(30) NOT NULL,
  first_name VARCHAR(60) NOT NULL,
  last_name VARCHAR(60) NOT NULL,
  email VARCHAR(255) NOT NULL,
  enrollment_year YEAR NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_students_reg_no UNIQUE (reg_no),
  CONSTRAINT uq_students_email UNIQUE (email),
  CONSTRAINT chk_students_status CHECK (status IN ('active','suspended','graduated','withdrawn')),
  CONSTRAINT fk_students_department FOREIGN KEY (department_id)
    REFERENCES departments(department_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE courses (
  course_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  department_id INT UNSIGNED NOT NULL,
  lecturer_id INT UNSIGNED NULL,
  course_code VARCHAR(20) NOT NULL,
  course_name VARCHAR(200) NOT NULL,
  credits TINYINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_courses_code UNIQUE (course_code),
  CONSTRAINT chk_courses_credits CHECK (credits BETWEEN 1 AND 30),
  CONSTRAINT fk_courses_department FOREIGN KEY (department_id)
    REFERENCES departments(department_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_courses_lecturer FOREIGN KEY (lecturer_id)
    REFERENCES lecturers(lecturer_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE enrollments (
  student_id INT UNSIGNED NOT NULL,
  course_id INT UNSIGNED NOT NULL,
  enrolled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status VARCHAR(20) NOT NULL DEFAULT 'enrolled',
  CONSTRAINT pk_enrollments PRIMARY KEY (student_id, course_id),
  CONSTRAINT chk_enrollments_status CHECK (status IN ('enrolled','dropped','completed')),
  CONSTRAINT fk_enrollments_student FOREIGN KEY (student_id)
    REFERENCES students(student_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_enrollments_course FOREIGN KEY (course_id)
    REFERENCES courses(course_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE student_course_performance (
  student_id INT UNSIGNED NOT NULL,
  course_id INT UNSIGNED NOT NULL,
  continuous_assessment DECIMAL(5,2) NOT NULL DEFAULT 0,
  exam_score DECIMAL(5,2) NOT NULL DEFAULT 0,
  -- Stored generated column avoids update anomalies on totals (BCNF-friendly)
  final_score DECIMAL(5,2) GENERATED ALWAYS AS (continuous_assessment + exam_score) STORED,
  grade_letter CHAR(2) NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_scp PRIMARY KEY (student_id, course_id),
  CONSTRAINT chk_scores_ca CHECK (continuous_assessment BETWEEN 0 AND 100),
  CONSTRAINT chk_scores_exam CHECK (exam_score BETWEEN 0 AND 100),
  CONSTRAINT fk_scp_student FOREIGN KEY (student_id)
    REFERENCES students(student_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_scp_course FOREIGN KEY (course_id)
    REFERENCES courses(course_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ===========================================
-- Extensions required by Part A (BCNF-focused)
-- ===========================================

-- 1) Course Materials: materials (id, course_id, file_name, file_type, upload_date, file_path, file_size)
CREATE TABLE materials (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  course_id INT UNSIGNED NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  file_type VARCHAR(20) NOT NULL,
  upload_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  file_path VARCHAR(500) NOT NULL,
  file_size BIGINT UNSIGNED NOT NULL,
  CONSTRAINT chk_materials_file_type CHECK (file_type IN ('pdf','docx','pptx','xlsx','csv','mp4','link','other')),
  CONSTRAINT chk_materials_file_size CHECK (file_size >= 0),
  CONSTRAINT uq_materials_course_path UNIQUE (course_id, file_path),
  CONSTRAINT fk_materials_course FOREIGN KEY (course_id)
    REFERENCES courses(course_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2) LMS Activity Logs:
-- activity_logs(id, student_id, activity_type, resource_id, timestamp, session_duration, ip_address)
CREATE TABLE activity_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_id INT UNSIGNED NOT NULL,
  activity_type VARCHAR(30) NOT NULL,
  resource_id BIGINT UNSIGNED NULL,
  `timestamp` DATETIME(3) NOT NULL,
  session_duration INT UNSIGNED NOT NULL DEFAULT 0,
  ip_address VARCHAR(45) NOT NULL,
  -- Required CHECK constraint for activity_type
  CONSTRAINT chk_activity_type CHECK (
    activity_type IN (
      'login','logout','view_material','download_material',
      'watch_video','attempt_quiz','submit_assignment',
      'forum_post','message'
    )
  ),
  CONSTRAINT chk_session_duration CHECK (session_duration >= 0),
  CONSTRAINT chk_ip_not_empty CHECK (CHAR_LENGTH(ip_address) >= 7),
  CONSTRAINT fk_activity_student FOREIGN KEY (student_id)
    REFERENCES students(student_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 3) Smart Classroom Sensors:
-- sensors(sensor_id, room_id, sensor_type, manufacturer, installation_date)
CREATE TABLE sensors (
  sensor_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  room_id INT UNSIGNED NOT NULL,
  sensor_type VARCHAR(30) NOT NULL,
  manufacturer VARCHAR(120) NOT NULL,
  installation_date DATE NOT NULL,
  -- Required CHECK constraint for sensor_type
  CONSTRAINT chk_sensor_type CHECK (
    sensor_type IN ('temperature','humidity','occupancy','energy','co2','light')
  ),
  CONSTRAINT fk_sensors_room FOREIGN KEY (room_id)
    REFERENCES rooms(room_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 4) Sensor Readings:
-- sensor_readings(id, sensor_id, value, timestamp, status)
CREATE TABLE sensor_readings (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sensor_id INT UNSIGNED NOT NULL,
  value DECIMAL(12,4) NOT NULL,
  `timestamp` DATETIME(3) NOT NULL,
  status VARCHAR(10) NOT NULL DEFAULT 'OK',
  CONSTRAINT chk_sensor_status CHECK (status IN ('OK','WARN','ERROR')),
  -- Prevent duplicate readings for same sensor at same instant
  CONSTRAINT uq_sensor_readings UNIQUE (sensor_id, `timestamp`),
  CONSTRAINT fk_readings_sensor FOREIGN KEY (sensor_id)
    REFERENCES sensors(sensor_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;
