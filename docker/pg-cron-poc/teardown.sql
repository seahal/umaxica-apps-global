-- Unschedule every pg_cron_poc job. Leaves the pg_cron_poc schema/table in
-- place for repeatable re-runs. See README.md for full-removal instructions.

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname IN ('pg_cron_poc_heartbeat', 'pg_cron_poc_failure');

SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname IN ('pg_cron_poc_heartbeat', 'pg_cron_poc_failure');
