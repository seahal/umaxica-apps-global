# GH-584: Address Authentication and Security Concerns

GitHub: #584

## Summary

6 annotations flag security-sensitive issues in authentication controllers and risk modules.

## Affected Files

### Unknown methods in auth concerns

- `app/controllers/concerns/authentication/staff.rb:71` — `what is this method?`
- `app/controllers/concerns/authentication/user.rb:67` — `what is this method?`
- `app/controllers/concerns/authentication/viewer.rb:73` — `what is this method?`

### CSRF protection disabled

- `app/controllers/sign/app/tokens_controller.rb:8` — CSRF disabled by nullifying session
- `app/controllers/sign/org/tokens_controller.rb:9` — CSRF disabled by nullifying session

### Risk module concerns

- `app/lib/sign/risk/emitter.rb:7` — PostgreSQL INSERT latency vs Redis ZADD; consider Redis
- `app/lib/sign/risk/enforcer.rb:39` — Step-up authentication flag needs persistent storage

## Action

1. Investigate the unknown methods in auth concerns — document or remove.
2. Evaluate whether CSRF disabling in token controllers is safe; document rationale or restore.
3. Assess PostgreSQL-based risk emission performance and decide on Redis migration.
4. Implement persistent storage for step-up authentication flags.
5. Remove all FIXME annotations once resolved.

## Implementation Status (2026-04-07)

**Status: NOT STARTED**

All 7 annotations remain in the codebase:

- 3 unknown method annotations in auth concerns (staff, user, viewer).
- 2 CSRF null_session overrides in token controllers.
- 2 risk module performance/storage notes (emitter, enforcer).

## Improvement Points (2026-04-07 Review)

- Split the issue by risk class. Token-endpoint CSRF, persistent step-up state, and risk emitter
  performance should not compete inside one umbrella FIXME note.
- Add explicit closure evidence per item: code owner, affected files, and tests. Without that, FIXME
  cleanup will stay subjective.
