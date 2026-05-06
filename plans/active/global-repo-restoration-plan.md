# Global Repository Restoration Plan (2026-04-26)

## Status

Active (2026-04-26). Working list of items to re-apply after the repository was reverted from a
degraded state. To be implemented incrementally by another agent.

## Context for the implementing agent

This repository was rolled back to recover from a degraded state. Many ADRs in `adr/` describe
initiatives that were lost in the rollback and need to be re-applied. Before doing any of this work,
read the following so the new context is clear:

- `adr/split-into-regional-and-global-repos.md` (2026-04-25, **Accepted**) — the load-bearing
  context. The Rails Engine strategy and the 4-app split strategy are both **abandoned**. This repo
  is now one ordinary Rails application that serves the **global** surface only:
  - **IdP** on `id.*.{app,com,org}` (renamed from `sign.*`)
  - **RP** on `www.*.{app,com,org}`
  - `idp + rp = 1` — one Gemfile, one Zeitwerk load path, one app boot.
- Regional surfaces (docs, news, help) live in a separate repository and are **out of scope here**.
- The `Jit::<Engine>::` namespace, the `engines/` tree, and the `apps/<name>/` wrapper apps are all
  retired. Do not introduce new code under those layouts.

### Hard constraints

1. **No engine work.** Do not add to `engines/`. Do not introduce `Jit::*` namespacing. Do not
   re-create `apps/identity`, `apps/zenith`, `apps/foundation`, or `apps/distributor`. Anything that
   reads as "per-engine" or "per-app" in the source ADRs must be re-shaped for a single Rails app.
2. **No regional surface work.** Skip anything that targets `docs.*`, `news.*`, `help.*`, or
   `Regional` engine. That belongs to the other repository.
3. **`sign.*` → `id.*` rename is in flight.** When updating WebAuthn RP ID, `TRUSTED_ORIGINS`, OIDC
   issuer / discovery URL, OAuth client redirect URIs, CSP, Permissions-Policy, cookie domain, route
   host constraints, fixtures, and dev hosts, target `id.*`. Treat references to `sign.*` as legacy.
4. **Frontend toolchain is Rails Importmap + Vite+ (`vp`).** Bun is **not** used. Biome is **not**
   used either — the project migrated to Vite+, and `vp check` covers both lint and format (Vite+
   wraps Oxlint / Oxfmt internally). The underlying package manager remains pnpm (lockfile is
   `pnpm-lock.yaml`); package operations go via `vp add` / `vp install`. Run `vp check` (lint +
   format check) and `vp check --fix` (auto-fix) instead of any direct `biome`, `eslint`,
   `prettier`, or `bunx` invocation.
5. **Do not commit automatically.** Per `AGENTS.md`, never run `git commit`. Report what was done
   and stop.
6. **Tests are mandatory** for every change, per `AGENTS.md`. Prefer minitest without mocks (t_wada
   style). Avoid `any_instance.stub`.
7. **Structured logging:** prefer `Rails.event.record(...)` / `Rails.event.error(...)` over
   `Rails.logger.*` for new application logs.

### Adaptation rule of thumb

Each source ADR was authored under one of three structural assumptions: (a) Rails Engine, (b) 4-app
split, or (c) single-app — assumption (c) ports cleanly; (a) and (b) need a translation pass. When
re-applying:

- Replace `Jit::Foundation::Base::...` → `Base::...` (drop the engine prefix; keep the surface
  segment such as `Sign`, `App`, `Org`, `Com`, `Base`, `Acme`).
- Replace per-engine cache/queue DBs → single-app `cache`/`queue` DBs.
- Replace per-engine `Current` → one app-level `Current` (the _split-by-engine_ current-context ADR
  is obsolete; revisit `Current` shape only if the implementer judges it necessary).
- Replace `signature.*_path` / `foundation.*_path` route helpers → main app helpers.

If a source ADR cannot be reasonably ported (it was purely about engine routing proxies, wrapper-app
boot, etc.), skip it and note "obsolete by structure, no work needed" in the plan log.

---

## Work Items

Items are grouped by category. Each item lists:

- **Source ADR / note** — primary reference document.
- **Goal** — what re-applying this means in the single-app world.
- **Key surface** — files, controllers, services, or tables most likely to be touched.
- **Verification** — minimum to consider the item done.
- **Adaptation notes** — where the source assumed engines / 4-apps and how to remap.

Within each category, items are ordered by suggested execution sequence (earliest first).

---

### A. Security / Authentication

These are the highest-risk and highest-value items. Most were already partially designed; the work
is to land the design into the single-app layout.

#### A1. Email OTP race condition fixes

- **Source:** `adr/email-otp-race-condition-fixes.md`
- **Goal:** Eliminate races in email OTP issuance and verification. Use `update_all` for atomic
  counter increments and `SELECT ... FOR UPDATE` (or equivalent) inside a transaction for
  consume-on-verify.
- **Key surface:** Email OTP service / controller pair (verification, throttling, attempt counter).
  Touch the OTP model and any OTP-related rate-limit code path.
- **Verification:** Add concurrency tests that hit the verify path with two simultaneous attempts on
  the same OTP — only one should succeed; counters and `consumed_at` must be consistent.
- **Adaptation notes:** Keep it inside the single app's `app/services/...` and `app/models/...`. No
  engine prefix.

#### A2. Refresh / revoke / AAL downgrade and replay hardening

- **Source:** `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- **Goal:** Block AAL downgrade on refresh; reject replays of refresh tokens; ensure revocation
  cascades correctly. Tighten the refresh path so a stolen refresh token cannot be used to obtain a
  lower-AAL session that bypasses step-up.
- **Key surface:** Refresh-token service, session model, OAuth/OIDC token endpoint, AAL evaluator.
- **Verification:** Integration tests that (a) attempt refresh after revoke, (b) attempt to reuse a
  rotated refresh token, (c) confirm the new access token's AAL ≥ original. Audit emit on each
  rejection.
- **Adaptation notes:** The token endpoint now lives in the global repo (no `Jit::Identity`).

#### A3. OIDC authn hardening implementation decisions

- **Source:** `adr/oidc-authn-hardening-implementation-decisions.md`,
  `adr/notes/oidc-authn-hardening-handoff.md`, `adr/notes/oidc-callback-integration-tests.md`
- **Goal:** Land the OIDC hardening decisions: PKCE S256 enforcement, `redirect_uri` exact-match,
  nonce / `auth_time` / `acr` / `amr` / `sid` / `subject_type` claim handling.
- **Key surface:** Authorize endpoint, token endpoint, ID token builder, claim assemblers, callback
  validator. Fixtures and integration tests for the callback path.
- **Verification:** OIDC callback integration tests (the ADR notes call them out specifically). All
  invalid-PKCE / mismatched-redirect / replayed-code paths must reject with the correct error code.
- **Adaptation notes:** The issuer URL is now `https://id.<apex>` (not `sign.*`). Update issuer,
  discovery URL, JWKS URL fixtures.

#### A4. OIDC claims model

- **Source:** `adr/oidc-claims-decision.md`, `adr/notes/oidc-claims-model.md`,
  `adr/notes/oidc-session-model.md`
- **Goal:** Lock in the claims model (subject_type, sid, sub, scoped claims) and the session model
  that backs it.
- **Key surface:** Claim assembler service, session model, ID-token JWT builder.
- **Verification:** Unit tests for each claim type; round-trip test that the issued ID token decodes
  back to the expected claim set for representative scopes.
- **Adaptation notes:** None structural; this work is already single-app friendly.

#### A5. OAuth 2.1 compliance gap items

- **Source:** `adr/notes/oauth2-1-compliance-gap.md`
- **Goal:** Close the residual OAuth 2.1 gaps listed in the note (PKCE required for confidential
  clients too, removal of implicit flow remnants, redirect_uri exact match, no plaintext code
  challenge, etc.).
- **Key surface:** Authorize endpoint, client model, token endpoint validators.
- **Verification:** A compliance-style test suite that walks through each gap item with a positive
  and a negative case.
- **Adaptation notes:** Same as A3 — single-app, `id.*` issuer.

#### A6. Token endpoint CSRF / hardening (gh611)

- **Source:** `adr/notes/gh611-harden-token-endpoints-csrf.md`
- **Goal:** Ensure token endpoints have correct CSRF posture (none for `application/json` token
  endpoints invoked by clients; CSRF on browser-driven endpoints), and the hardening described in
  the note (rate limit, locked client auth, etc.).
- **Key surface:** Token controller, application controller CSRF posture, rate-limit middleware /
  service.
- **Verification:** Tests for both legitimate client calls and CSRF replay attempts. Confirm
  `protect_from_forgery` posture matches the design.

#### A7. Self-service session revoke (gh634)

- **Source:** `adr/notes/gh634-self-service-revoke-sessions.md`
- **Goal:** A signed-in user can list their active sessions and revoke any of them (including
  current). Revocation must invalidate refresh tokens and any cached AAL.
- **Key surface:** A "sessions" view under the account/security area; the session model; session
  revoke service.
- **Verification:** UI and controller tests that list sessions and revoke one; integration test that
  the revoked session cannot perform any subsequent authenticated action.

#### A8. CSP and Permissions-Policy

- **Source:** `adr/csp-and-permissions-policy.md`
- **Goal:** Ship the documented Content-Security-Policy and Permissions-Policy headers. Tighten in
  the order the ADR prescribes (report-only → enforce).
- **Key surface:** `config/initializers/content_security_policy.rb` (or equivalent), middleware /
  layout that emits Permissions-Policy.
- **Verification:** Request specs that assert headers on representative routes (HTML page, JSON API,
  OIDC pages).
- **Adaptation notes:** Allow-list hosts must include `id.*` and `www.*`, drop `sign.*`. WebAuthn
  related directives must reflect the new RP ID.

#### A9. Turnstile environment toggle

- **Source:** `adr/turnstile-environment-toggle.md`
- **Goal:** Cloudflare Turnstile is environment-toggleable (enabled in prod, off / mocked in test
  and dev) so that test runs do not depend on Cloudflare and dev does not require live keys.
- **Key surface:** Turnstile verifier service, an env-driven configuration shim, the controllers
  that gate on Turnstile (sign-in, recovery, etc.).
- **Verification:** Tests run without Turnstile keys; explicit test that the production-mode
  verifier rejects an empty token.

#### A10. Sign Configuration sprint spec

- **Source:** `adr/sign-configuration-sprint-spec.md`
- **Goal:** Land the sprint spec items (multi-factor enrollment flow, recovery codes, TOTP, passkey
  enrollment, etc.) into the global app.
- **Key surface:** `app/controllers/sign/...`, `app/views/sign/...`, the corresponding services.
- **Verification:** Per-flow integration tests; confirm each MFA method enrolls, verifies, and
  revokes cleanly.
- **Adaptation notes:** Path stays `sign/*` (the URL surface name is unchanged); the _hostname_
  changes to `id.*`. Do not invent a new namespace.

---

### B. Data model / Database

These items reshape data ownership. Run them after Section A's auth invariants are stable, because
several touch tables that auth code reads.

#### B1. Account / Workspace / Avatar / Billing structure

- **Source:** `adr/account-workspace-avatar-billing.md`
- **Goal:** Land the account/workspace/avatar/billing model the ADR specifies. One unified app means
  there is no longer a need to split this across "engines" — pure Rails models under `app/models/`.
- **Key surface:** Account, Workspace, Avatar, Billing models and their migrations; policies that
  scope operations on workspaces.
- **Verification:** Model tests for each entity; system test that creates an account, joins a
  workspace, sets an avatar, and views billing.

#### B2. SettingPreference: remove polymorphic owner

- **Source:** `adr/setting-preference-remove-polymorphic-owner.md`
- **Goal:** Replace the polymorphic owner association with explicit FK columns (per-owner-type table
  or per-owner-type FK column on a single table — follow the ADR's choice).
- **Key surface:** `SettingPreference` model, fixtures, any code that creates/queries preferences.
- **Verification:** Migration is reversible. Existing preference records (if any) round-trip through
  the new shape. No model still references the polymorphic `owner_type`/`owner_id` columns after the
  migration.
- **Adaptation notes:** This is one of the items called out in
  `adr/ongoing-engine-migration-state.md` as having already broken fixtures. Make the fixtures valid
  against the new shape as part of this work.

#### B3. Database consistency repair

- **Source:** `adr/database-consistency-repair-plan.md`
- **Goal:** Apply the consistency fixes — partial indexes, NOT-NULL constraints, CHECK constraints,
  FK indexes — that the ADR enumerates.
- **Key surface:** Migrations under `db/migrate/`. Schema dump.
- **Verification:** `bundle exec rails db:migrate` runs cleanly forward and backward. Each new
  constraint has a model-level validation that mirrors it (so violations are caught before the DB
  raises).

#### B4. Treeable CTE refactor

- **Source:** `adr/treeable-cte-refactor.md`
- **Goal:** Replace ad-hoc tree-walk code with a `Treeable` concern that uses recursive CTE
  (`with_recursive`). Apply it to the models the ADR names.
- **Key surface:** New `Treeable` concern; the models that adopt it; any view that walks
  ancestors/descendants.
- **Verification:** Tree-traversal tests that compare the CTE result to a reference Ruby walk on a
  small fixture set.

#### B5. Chronicle audit DB consolidation

- **Source:** `adr/chronicle-audit-db-consolidation.md`,
  `adr/activity-journal-chronicle-db-model-naming.md`
- **Goal:** Consolidate audit/log persistence into the Chronicle DB with the agreed naming. Audit
  emission paths use `chronicle` connection.
- **Key surface:** `database.yml`, audit emitter service, audit models, migrations under
  `db/chronicle_migrate/` (or whichever path the ADR settles on for the single-app layout).
- **Verification:** Audit emission test that writes to chronicle and reads back. Confirm the primary
  DB does not gain audit tables.
- **Adaptation notes:** This was originally written assuming 4 apps each with their own DBs. In the
  single-app world there is just `primary` and `chronicle` (and any others the consolidation ADR
  specifies). Drop per-app cache/queue DB language; it is replaced by C-section work.

---

### C. Cache / Queue infrastructure (single-app)

#### C1. Solid Cache + Solid Queue (single-app version)

- **Source:** Background only — `adr/four-app-solid-cache-and-solid-queue.md` is now obsolete (per
  its own banner). Re-introduce as a single-app concern.
- **Goal:** Solid Cache as `Rails.cache` backend; Solid Queue as `ActiveJob` adapter; Puma plugin
  hook for Solid Queue.
- **Key surface:** `config/cache.yml`, `config/queue.yml`, `config/database.yml` (cache + queue
  DBs), `config/puma.rb`, environment files.
- **Verification:** Cache write/read works in test and dev. A trivial job enqueues, executes, and
  records. `bin/dev` boots the queue without external services.
- **Adaptation notes:** **Do not** create per-app cache/queue databases — there is one app. One
  `cache` DB, one `queue` DB.

---

### D. Authorization

#### D1. Pundit → Action Policy migration

- **Source:** `adr/pundit-to-action-policy-migration.md`
- **Goal:** Replace Pundit with Action Policy across the codebase. Use
  `authorize :user, optional: true` where the original code allowed an unauthenticated path.
- **Key surface:** Every controller that calls `authorize`, `policy`, or `policy_scope`. The
  `app/policies/` tree. The `ApplicationController` authorization mixins.
- **Verification:** No remaining `Pundit` constant in the codebase. Existing controller tests pass.
  Add tests for any policy whose semantics changed.

---

### E. Contact / Auth integration

#### E1. Contact::ActorContext shared contract

- **Source:** `adr/notes/contact-auth-shared-contract.md`, `adr/notes/contact-auth-integration.md`
- **Goal:** A small typed value object representing the authenticated subject as far as Contact
  needs it. Used by Contact services instead of reaching into Auth internals.
- **Key surface:** New value object; refactor of Contact services to consume it; the auth side
  exposes a builder.
- **Verification:** Contact tests do not import auth model classes directly; they receive an
  `ActorContext` instance.

#### E2. Contact / auth customer canonicalization

- **Source:** `adr/notes/contact-auth-customer-canonicalization.md`
- **Goal:** Canonicalize how a Contact resolves to a customer / actor record so duplicate paths
  collapse.
- **Key surface:** Contact resolver service; the controller actions that take user-supplied contact
  identifiers.
- **Verification:** Tests covering each input shape (email, phone, etc.) resolving to the same
  canonical record.

---

### F. Preference / i18n / Frontend

#### F1. Localization preference flow (`ri` / `lx` / `tz`)

- **Source:** `adr/localization-preference-flow.md`
- **Goal:** Region (`ri`), locale (`lx`), and timezone (`tz`) preferences flow through the
  documented precedence (URL param > cookie > user pref > default). Apply uniformly across the
  global app.
- **Key surface:** `ApplicationController` `around_action` that sets I18n / Time.zone; the cookie
  jar setup; the user preference model.
- **Verification:** Request specs covering each precedence rung.

#### F2. Theme preference cookie + param contract (`ct`)

- **Source:** `adr/theme-preference-cookie-and-param-contract.md`
- **Goal:** Theme (`ct`) preference uses the cookie + param contract documented in the ADR.
- **Key surface:** `ApplicationController`, layout that reads the resolved theme, cookie writer.
- **Verification:** Request spec that flips theme via param, confirms cookie is written, and that
  subsequent requests pick up the cookie.

#### F3. i18n inline `default:` literal ban

- **Source:** `adr/notes/i18n-inline-default-literal-rule.md`
- **Goal:** Forbid inline `default:` literal strings on `t(...)` / `I18n.t` calls. Enforce via lint
  rule (custom rubocop cop or equivalent) so missing keys surface in the locale files instead of
  hiding behind defaults.
- **Key surface:** Lint configuration; sweep through `app/views/`, `app/helpers/`,
  `app/controllers/` to remove inline defaults; fill gaps in `config/locales/`.
- **Verification:** Lint passes; full text of every used key is present in `en` and `ja` (or
  whichever locales are in scope).

#### F4. Frontend toolchain: Rails Importmap + Vite+ (`vp`)

- **Source:** `adr/frontend-architecture-toolchain.md` (the file itself still says "Bun" and may
  also say "Biome"; both are out of date — see Adaptation notes).
- **Goal:** Confirm the documented frontend toolchain matches reality:
  - **Rails Importmap** for shipping ES modules to the browser.
  - **Vite+** (`vp`) is the unified toolchain wrapper. `vp check` runs both lint and format in one
    pass; `vp check --fix` auto-fixes. Vite+ wraps Oxlint / Oxfmt internally — do not invoke them,
    Biome, ESLint, or Prettier directly.
  - **pnpm** is the underlying package manager (lockfile is `pnpm-lock.yaml`; there is no
    `bun.lockb`). Package operations go via `vp add` / `vp install`.
  - **Stimulus / Hotwire / Turbo** as the JS layer.
  - `package.json` should expose `check` (= `vp check`) and `fix` (= `vp check --fix`) scripts so
    `pnpm run check` / `pnpm run fix` work for editors and CI.
- **Key surface:** `package.json` (scripts), `pnpm-lock.yaml`, `Dockerfile` multi-stage build,
  `bin/dev`, CI config, any docs that mention "Bun" or "Biome".
- **Verification:** Fresh clone → `vp install` → `vp dev` boots. `vp check` exits 0 on a clean tree.
  CI uses `voidzero-dev/setup-vp` (or pnpm directly) and runs `vp check` + `vp test`. No `bun`,
  `bun.lockb`, `biome`, `eslint`, or `prettier` binary or config referenced anywhere.
- **Adaptation notes:** The source ADR text says "Importmap + Bun" and earlier drafts of this plan
  said "Biome"; both are wrong. Real stack is **Importmap + Vite+ (vp) + pnpm**. Either rewrite the
  ADR (separate task) or treat this work item as the source of truth. Do **not** introduce Bun,
  Biome, ESLint, or Prettier.

---

### G. Test quality

#### G1. Remove `any_instance.stub`

- **Source:** `adr/notes/any-instance-stub-removal.md`
- **Goal:** Eliminate `any_instance.stub` (and `Mocha`-style `any_instance` patterns) in favor of
  dependency injection or real fixtures. Keeps test brittleness low and forces honest seams.
- **Key surface:** `test/` tree-wide. Refactor test setup and the production code seams the tests
  needed to stub.
- **Verification:** Grep finds zero `any_instance` matches in `test/`. Suite stays green.

#### G2. OIDC callback integration tests

- **Source:** `adr/notes/oidc-callback-integration-tests.md`
- **Goal:** Add the integration test set the note specifies (PKCE positive, PKCE-missing,
  redirect_uri mismatch, replayed code, expired code, AAL acceptance, claim assembly).
- **Key surface:** `test/integration/oidc/...`.
- **Verification:** Each scenario has a test that fails on regression.

---

### H. Audit findings (from `adr/audit/audit-findings-2026-03-30.md`)

The audit lists 136 findings (2 Critical, 33 High, 90 Medium, 8 Low). Re-apply the items below. Skip
any that the audit attributes to engine layout — those are mooted by the repo split.

#### H1. `TRUSTED_ORIGINS` for `localhost` (audit Critical)

- **Source:** `adr/audit/audit-findings-2026-03-30.md`, `adr/notes/env-trusted-origins.md`
- **Goal:** Dev / test must populate `TRUSTED_ORIGINS` correctly for the new `id.*` and `www.*`
  hosts, and `localhost` is allow-listed only in dev.
- **Key surface:** Environment loading, `config/initializers/...` that configures `TRUSTED_ORIGINS`,
  dev fixtures, CI env.
- **Verification:** WebAuthn registration / authentication ceremonies succeed in dev against the new
  hostnames; production rejects an unknown origin.
- **Adaptation notes:** The note `adr/notes/env-trusted-origins.md` may still describe the 4-engine
  layout. Re-shape for one app, two hosts (`id.*`, `www.*`).

#### H2. Contact IDOR fix (audit High)

- **Goal:** Close the contact-side IDOR identified in the audit. Authorization on every contact
  read/write goes through Action Policy (D1) rather than ad-hoc `current_user.contacts.find(id)`
  patterns.
- **Key surface:** Contact controllers and policies.
- **Verification:** Test that user A cannot read or write user B's contact, even by ID guess.

#### H3. God-class decomposition (audit High)

- **Goal:** Decompose the god classes the audit names (typically the auth/session orchestrators)
  into smaller services with clear responsibilities (SOLID, per AGENTS.md "Design Principles").
- **Key surface:** The specific classes the audit lists.
- **Verification:** Each new class has a focused test. Old call sites still pass.

#### H4. N+1 fixes (audit High)

- **Goal:** Fix the N+1 sites the audit lists. Use `includes` / `preload` per case.
- **Key surface:** Listing controllers / serializers the audit names.
- **Verification:** Each fix has a test that asserts query count (`assert_queries` or equivalent)
  before/after.

#### H5. Japanese hardcoded string sweep (audit Medium)

- **Goal:** Hardcoded Japanese strings move into `config/locales/ja.yml` with English equivalents in
  `en.yml`. Aligns with F3 (no inline `default:` literal).
- **Key surface:** Views, helpers, controller flash messages.
- **Verification:** Grep finds no hardcoded Japanese in `.erb` / `.rb` outside locale files. Pages
  render correctly in both `en` and `ja`.

---

## Out of scope (explicitly do **not** do here)

- Anything in `engines/`. Treat the directory as legacy until its contents are folded back into
  `app/` / `lib/` (separate clean-up task).
- Anything in `apps/identity`, `apps/zenith`, `apps/foundation`, `apps/distributor`. Same treatment.
- Per-engine `Current` boundary work (`adr/current-context-boundary-by-engine.md`). The split is
  obsolete.
- Per-engine cache / queue DBs (`adr/four-app-solid-cache-and-solid-queue.md`). Replaced by C1.
- Regional surfaces (docs, news, help). They are in the other repo.
- `news-is-timeline.md`, `regional-docs-news-content-model.md`,
  `regional-help-surface-direction.md`. Out-of-scope for this repo.
- Engine extraction notes (`adr/notes/engine-extraction-phase-1-skeleton.md`,
  `adr/notes/engine-extraction-prep-phase-4-and-6.md`). Obsolete.
- `adr/notes/gh661-activity-behavior-db-role-separation-cancelled.md`. Cancelled by its own banner.

---

## Suggested execution order

A small, sequenced first wave to minimize merge friction:

1. **C1** (cache/queue) — required by anything that touches background jobs or cache.
2. **D1** (Pundit → Action Policy) — most controllers depend on this; doing it early avoids
   re-touching every controller.
3. **A1, A2, A3, A4, A5, A6** (auth / OIDC hardening) — core safety items.
4. **A7, A8, A9, A10** (session revoke, CSP, Turnstile, sprint spec).
5. **B1, B2, B3, B4, B5** (data model / DB).
6. **E1, E2** (contact / auth integration).
7. **F1, F2, F3, F4** (preference / i18n / frontend).
8. **G1, G2** (test quality).
9. **H1–H5** (audit findings) — interleaved with the above where they overlap, otherwise last.

Within each item, follow the standard cycle: read the source ADR → write a failing test → make it
pass → update related fixtures → run `vp check` and `vp test` → run `bundle exec rails test` → run
`bundle exec rubocop`, `bundle exec erb_lint --lint-all`, `bundle exec brakeman --no-pager` → stop
without committing.

---

## Reporting

For each item, leave a short note (commit message draft is fine) summarizing:

- which ADR was the source,
- which files changed,
- what tests were added,
- any deviation from the source ADR and its reason.

Do not run `git commit`. Hand control back to the human after each item.
