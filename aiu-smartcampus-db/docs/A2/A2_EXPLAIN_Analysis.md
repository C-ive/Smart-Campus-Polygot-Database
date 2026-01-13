# Part A (2) — EXPLAIN ANALYZE Analysis

This folder contains:
- A2_EXPLAIN_BEFORE.txt (plans before A2 indexing)
- A2_EXPLAIN_AFTER.txt  (plans after A2 indexing)
- A2_SHOW_INDEXES.txt   (proof of created indexes)

## Q1: Student activity pattern analysis
**Goal:** Analyze a student’s last-30-days activity by type (COUNT/SUM/MIN/MAX).

**Expected improvement after indexing**
- Before: MySQL can use FK index on student_id, but will filter timestamp after lookup (more row reads).
- After: `idx_activity_student_time (student_id, timestamp)` enables a tighter range scan on both columns.
- The reporting-heavy columns are covered by `idx_activity_cover_report (student_id, timestamp, activity_type, session_duration)`, which reduces table lookups during aggregation.

**What to look for in EXPLAIN ANALYZE**
- Range scan or index range on activity_logs using idx_activity_student_time or idx_activity_cover_report
- Fewer “rows examined” and lower actual time after indexes

## Q2: Sensor data correlation query
**Goal:** Correlate temperature and occupancy readings for the same room using timestamp alignment.

**Expected improvement after indexing**
- `idx_sensors_room_type (room_id, sensor_type)` reduces sensor lookup cost (temperature + occupancy sensors in room)
- `uq_sensor_readings (sensor_id, timestamp)` supports fast equality join on (sensor_id + timestamp)
- `idx_readings_time (timestamp)` helps time-window filters when plans consider timestamp constraints early

**What to look for in EXPLAIN ANALYZE**
- Index lookups on sensors via idx_sensors_room_type
- Indexed joins on sensor_readings via uq_sensor_readings
- Reduced nested loop work after indexes

## Q3: Cross-table analytics query
**Goal:** Identify at-risk students by combining: enrollment count, avg performance, and last-90-days activity time.

**Expected improvement after indexing**
- `idx_students_status (status)` avoids scanning all students when filtering by active status
- `idx_activity_student_time` reduces the cost of joining activity logs within a 90-day window

**What to look for in EXPLAIN ANALYZE**
- Student filtering uses idx_students_status
- Activity log join uses idx_activity_student_time and shows lower actual time than before

## View Deliverable
A2_VIEW_PROOF.txt shows:
- `SHOW CREATE VIEW vw_student_activity_agg`
- Sample top rows by total activity time

The view consolidates student demographics and aggregate activity metrics (counts, total seconds, last activity), supporting dashboards and reporting.
