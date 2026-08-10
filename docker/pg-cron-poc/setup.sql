-- Isolated pg_cron infrastructure PoC. Local-only. See README.md.
-- Idempotent: safe to re-run.

CREATE SCHEMA IF NOT EXISTS cron_poc;

CREATE TABLE IF NOT EXISTS cron_poc.heartbeat (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  executed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  server_version text NOT NULL DEFAULT current_setting('server_version')
);

-- Unschedule any PoC jobs left over from a prior run before rescheduling.
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname IN ('pg_cron_poc_heartbeat', 'pg_cron_poc_failure');

SELECT cron.schedule(
  'pg_cron_poc_heartbeat',
  '* * * * *',
  $$INSERT INTO cron_poc.heartbeat DEFAULT VALUES$$
);

-- Deliberately references a nonexistent PoC-only table to prove failed-job
-- visibility in cron.job_run_details without touching any real table.
SELECT cron.schedule(
  'pg_cron_poc_failure',
  '* * * * *',
  $$INSERT INTO cron_poc.nonexistent_table DEFAULT VALUES$$
);

SELECT jobid, jobname, schedule, database, username, active, command
FROM cron.job
ORDER BY jobid;
