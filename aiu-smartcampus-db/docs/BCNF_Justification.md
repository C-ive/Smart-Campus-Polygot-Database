# BCNF Justification (Part A.1)

## Why this schema is BCNF-ready
Each table is designed so that:
- Every non-key attribute is functionally dependent on a candidate key
- Join tables (ENROLLMENTS, STUDENT_COURSE_PERFORMANCE) use composite primary keys to avoid partial dependencies

### Key decisions
- ENROLLMENTS uses (student_id, course_id) as PK: status/enrolled_at depend on the full relationship.
- STUDENT_COURSE_PERFORMANCE uses (student_id, course_id) as PK: scores depend on the specific student-course pairing.

## Conscious performance-oriented choices (minor denormalization)
- MATERIALS.file_type is stored (could be derived from file_name). Stored to support fast filtering and consistent validation.
- STUDENT_COURSE_PERFORMANCE.final_score is a STORED generated column to prevent update anomalies and speed reporting.
- ACTIVITY_LOGS stores session_duration directly rather than reconstructing sessions from start/stop events; this supports analytics queries efficiently.

## Constraints required by the brief
- CHECK(sensor_type IN ...) on SENSORS
- CHECK(activity_type IN ...) on ACTIVITY_LOGS
These are implemented directly in the DDL.

## Notes
- Column name `timestamp` is kept exactly as required; it is backticked in DDL to avoid keyword ambiguity in MySQL.
