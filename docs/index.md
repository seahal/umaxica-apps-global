# Documentation Index

Repository documents are separated by purpose.

- `docs/` contains current, stable documentation for the single Rails app, its `app` / `org` / `com`
  surfaces, and the repository boundary with the separate regional codebase.
- `plans/` contains future work, proposals, drafts, migration plans, and backlog notes.
- `adr/` contains accepted architecture and design decisions, including rationale and tradeoffs.
- `notes/` contains non-authoritative ADR-adjacent notes and implementation handoff notes.
- `memo/` contains exploratory observations and rough analysis that do not affect implementation.

Rules:

- Keep non-authoritative implementation notes out of `docs/`, `plans/`, and `adr/`; use `notes/`
  instead.
- Keep exploratory notes that do not affect implementation in `memo/`.
- Keep future-facing material out of `docs/`.
- Keep stable operational guidance out of `plans/`.
- Record major accepted design decisions in `adr/`.
- When a plan is implemented, update `docs/`.

Current content-model references:

- `docs/architecture/actor-naming.md`
- `docs/architecture/database-boundaries.md`
- `docs/architecture/controller-boundaries.md`
- `docs/architecture/controller-lifecycle.md`
- `docs/architecture/preference.md`
- `docs/security/session-limit.md`
- `docs/security/authentication-assurance-levels.md`
- `docs/security/step-up-mfa-status.md`
- `docs/security/mfa-reset-account-recovery.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/refresh-token-rotation.md`
- `docs/security/identifier-hmac-emergency-rotation.md`
- `docs/security/cookie-domain-scope.md`
- `docs/security/social-login-provider-scope.md`
- `docs/security/session-reset-policy.md`
- `docs/security/sign-withdrawal-and-membership.md`
- `docs/reference/forbidden-rails-methods.md`
- `docs/reference/ruby-static-analysis.md`
