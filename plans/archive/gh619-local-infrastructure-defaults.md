# GH-619: Tighten Local Infrastructure Defaults

GitHub: #619

## Summary

Address operational issues around local boot behavior, PostgreSQL credentials, and pre-commit
automation safety.

## Scope

- Change the `core` service command in local compose config so it boots Rails instead of
  `sleep infinity`.
- Replace hardcoded `trust` auth and static Postgres passwords with environment-driven credentials.
- Replace `rubocop -A` in pre-commit automation with `--safe-auto-correct` or narrow the scope.

## Acceptance Criteria

- Local compose boot starts the intended app process.
- Database services read credentials from environment/config instead of fixed inline values.
- Pre-commit automation no longer applies unsafe RuboCop cops by default.

## Notes

These changes touch operational configuration and require explicit human review before merge.

## Implementation Status (2026-04-07)

**Status: CLOSED 2026-05-10**

- `core` now starts `bin/dev` instead of `sleep infinity`.
- Compose injects PostgreSQL user/password/database and replication credentials from environment
  variables with local-only defaults.
- Postgres host authentication now uses `scram-sha-256`; `POSTGRES_HOST_AUTH_METHOD: trust` and
  fixed inline `password` values were removed.
- Primary init and replica bootstrap scripts read passwords from environment variables instead of
  hardcoded values.
- Pre-commit automation was verified: `lefthook.yml` runs `bundle exec rubocop` as a check and does
  not run `rubocop -A` / unsafe all-cop autocorrection.
- Rollback: change `core.command` back to `sleep infinity`, restore `trust` HBA entries, and remove
  the Compose environment overrides if a local developer stack is blocked. Do not keep that rollback
  as the long-term default.

## Improvement Points (2026-04-07 Review)

- Keep the three changes as separate reviewable slices: compose boot command, database credentials,
  and pre-commit automation.
- Add a local rollback note for each slice. This plan changes developer environment defaults and
  should stay easy to back out.
