## 2026-06-14T00:00:00Z

- target: full coverage baseline
- command run: COVERAGE=true bin/rails test test/
- finding: the suite aborted before tests ran because PostgreSQL host `primary` could not be
  resolved.
- evidence: `ActiveRecord::DatabaseConnectionError` and `PG::ConnectionBad` during test schema
  maintenance; SimpleCov reported `Line Coverage: 50.27%` and `Branch Coverage: 0.59%` from the
  aborted run.
- decision: stop coverage work until the test database environment is repaired outside the allowed
  file set.

## 2026-06-14T22:00:00Z

- target: low-risk coverage additions in services and job wrappers
- command run:
  `bin/rails test test/services/sign_secret_schedule_deletion_test.rb test/services/identity_passkey_ceremony_transaction_purger_test.rb test/jobs/passkey_ceremony_transaction_purge_job_test.rb`
- finding: the added test classes hit a repository-wide fixture foreign-key validation failure
  before assertions ran.
- evidence: `PG::ForeignKeyViolation` on `org_preference_time_formats.preference_id` during fixture
  loading.
- decision: remove the added tests and avoid a partial fix that depends on broader fixture repair
  outside the allowed file set.

## 2026-06-14T22:20:00Z

- target: dead code removal candidate
- command run:
  `rg -n "SignSecretScheduleDeletion|PasskeyCeremonyTransactionPurgeJob|IdentityPasskeyCeremonyTransactionPurger" app test -g '*.rb'`
- finding: `SignSecretScheduleDeletion` has no direct references in `app/` or `test/`; only its own
  definition was found.
- evidence: search output returned only the class definition in
  `app/services/sign_secret_schedule_deletion.rb`.
- decision: delete `app/services/sign_secret_schedule_deletion.rb` as proven unused; keep the job
  and purger because the job still calls the purger and could be framework-scheduled.
