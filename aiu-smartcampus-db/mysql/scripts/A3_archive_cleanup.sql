-- mysql/scripts/A3_archive_cleanup.sql
-- Run this any time to move logs older than 1 year to archive (via trg_archive_activity)

USE aiu_urms_ext;

DELETE FROM activity_logs
WHERE `timestamp` < NOW() - INTERVAL 1 YEAR;
