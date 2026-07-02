# Security Enhancements

## Dynamic Application Security Testing (DAST)

To further enhance security, we should incorporate a DAST tool like OWASP ZAP into our CI/CD
pipeline.

### Plan

1. **Choose a DAST tool**: OWASP ZAP is the default candidate because it is open source, scriptable,
   and can run baseline scans without browser automation ownership in this repository.
2. **Target environment**: run against a deployed, disposable staging or preview environment with
   production-like security headers and seeded non-sensitive accounts. Do not scan developer
   localhost, production, or shared long-lived staging by default.
3. **Authenticated screens**: start with unauthenticated routes and health/read-only contracts.
   Add authenticated scans only after test accounts, login bootstrap, session cleanup, and
   rate-limit allowances are explicitly designed. Scanner credentials must be scoped to synthetic
   users with no real personal data.
4. **Cadence**: run the baseline scan nightly at first. Add PR-level scans only for changed route
   clusters or a short passive/baseline profile once runtime and false-positive costs are known.
5. **Secret handling**: store scanner credentials and target URLs in CI secrets. Never print cookies,
   bearer tokens, CSRF tokens, OTPs, or full request bodies in scan logs or uploaded artifacts.
6. **False-positive triage**: require an allowlist file owned by security/app maintainers. Each
   ignored finding needs a reason, route, evidence date, and review date.
7. **Fail conditions**: initially fail only on new high or critical findings that are not on the
   reviewed allowlist. Medium findings should create triage output without blocking until the
   baseline is clean.
8. **Responsibility split**: Rails security tests prove route contracts, authorization, CSRF, and
   model/service invariants. Brakeman and Semgrep cover static code patterns. DAST covers runtime
   HTTP behavior, headers, reflected input handling, and deployed configuration drift.
9. **CI integration**: implement the workflow in a future CI slice. This plan intentionally does not
   change `.github/workflows`.
