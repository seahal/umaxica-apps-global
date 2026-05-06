# Test Specification (TS)

## Project: Umaxica App (JIT)

### Aligned with IEEE 829 / ISO/IEC/IEEE 29119 Test Documentation

---

## 1. Introduction

### 1.1 Purpose

This TS defines how the Rails-based Umaxica App (JIT) will be verified across every public
surface—top, sign, help, docs, news, BFF, and API. It covers strategy, environments, tooling,
detailed cases, and acceptance criteria derived from the SRS and HLD.

### 1.2 References

- `docs/srs.md`
- `docs/hld.md`
- `docs/dds.md`
- `README.md`, `docs/checklist.md`
- IEEE 829 / ISO/IEC/IEEE 29119 guidance

---

## 2. Test Scope

### 2.1 In Scope

- Host-scoped routing and localization for `top`, `sign`, `help`, `docs`, `news`, `api`, `bff`
- Preference management (cookie consent, region/language/timezone, theme)
- Identity flows (registration, OTP, passkeys, OAuth placeholders, settings, withdrawal)
- Help-center contact submissions with Cloudflare Turnstile, OTP checks, and encrypted persistence
- API & BFF endpoints (health, inquiry validation, preference APIs)
- Security controls (JWT issuance, rate limiting, Turnstile, redirect whitelist, encryption)
- Observability (OpenTelemetry traces and health endpoints)
- Build/test automation (pnpm-managed JS tooling for linting/formatting and `bin/rails test`)

### 2.2 Out of Scope

- Non-Rails-hosted network endpoints (e.g., `asset-jp.umaxica.net`)
- External downstream services (e.g., GCP provisioning, Fastly caches) beyond smoke verification
- Third-party OAuth provider behavior (Google/Apple) beyond handshake scaffolding

---

## 3. Traceability

| SRS Section                     | TS Coverage |
| ------------------------------- | ----------- |
| §4.1 Cross-surface routing      | §7.1        |
| §4.2 Preference mgmt            | §7.2        |
| §4.3 Identity flows             | §7.3        |
| §4.4 Support/contact            | §7.4        |
| §4.5 API & BFF                  | §7.5        |
| §4.6 Data protection / security | §7.6, §8    |
| §5 Non-functional               | §8          |
| Acceptance criteria (AC-01..10) | §7 + §9     |

---

## 4. Test Approach

- **Unit tests (Ruby)**: `bin/rails test` covers models (e.g., `ServiceSiteContact`,
  `UserIdentityEmail`, `TimeBasedOneTimePassword`), controllers, concerns, services, consumers.
  Fixtures stored under `test/fixtures`; multi-database fixtures split by context.
- **Unit tests (JS/TS)**: `pnpm test` targets helpers (`views/passkey_helpers.js`, React utility
  modules) and ensures bundles remain deterministic.
- **Integration/system tests**: Rails system tests or Playwright scripts simulate flows (preference
  edits, registration, help contact).
- **API/contract tests**: Rswag or request specs verify `/api/v1/inquiry/*`, `/bff/*` payloads and
  headers.
- **Security tests**: RSpec/Minitest cases for rate limiting, JWT signature validation, redirect
  sanitization, Turnstile failure handling, PII encryption.
- **Performance tests**: k6 or wrk for `/sign` and `/help` flows; Lighthouse (or WebPageTest) for
  marketing pages. Target 300 ms p95 for health endpoints.
- **Observability verification**: OTEL traces appear in Tempo; Loki logs capture Turnstile failures;
  Grafana dashboards show request rate and application error signals.
- **Automation**: CI pipeline runs all tests plus linting (`pnpm run lint`, `pnpm run format`,
  `pnpm run check`, `bundle exec rubocop`, `bundle exec erb_lint`, `bundle exec brakeman`,
  `bundle exec bundler-audit`).

---

## 5. Test Environments

| Env                     | Purpose                                 | Stack                                                                                                                           |
| ----------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Local                   | Developer loop                          | Docker Compose (Postgres primaries/replicas, Valkey, MinIO, Loki, Tempo, Grafana), Foreman with Rails + pnpm-managed JS tooling |
| Staging                 | Integrated QA, performance & regression | Mirrors production hostnames, uses managed Postgres/Valkey, OTEL exports to staging Tempo                                       |
| Production Verification | Smoke tests post-deploy                 | Fastly/Cloudflare fronted hosts, managed infra                                                                                  |

**Data**: Seed states provided via fixtures; Compose services start with empty DBs. Sensitive data
must be synthetic. Contact forms require Turnstile test keys or bypass for automated runs.

---

## 6. Domain Behavior Matrix

| Surface           | Hosts                                                   | Coverage Focus                                                             |
| ----------------- | ------------------------------------------------------- | -------------------------------------------------------------------------- |
| Top::Com/App/Org  | `www.umaxica.com`, `www.umaxica.app`, `www.umaxica.org` | Redirect correctness, preference UIs, health endpoints                     |
| Sign::App/Org     | `id.umaxica.app`, `id.umaxica.org`                      | Registration (email/phone), passkey/TOTP, JWT cookies, logout, withdrawal  |
| Help::Com/App/Org | `help.umaxica.com`, etc.                                | Contact form validation, Turnstile, encrypted persistence, email/SMS hooks |
| Docs::_/News::_   | `docs.umaxica.*`, `news.umaxica.*`                      | Health endpoints, React hydration placeholder                              |
| API::\*           | `api.umaxica.*`                                         | `/health`, `/v1/health`, inquiry validation endpoints                      |
| BFF::\*           | `bff.umaxica.*`                                         | Preference APIs, locale propagation                                        |

---

## 7. Test Cases

### 7.1 Routing & Health

- **TC-ROUTE-001** Top root redirect (per host): GET `/` and expect 302 to `EDGE_*` host with
  `allow_other_host`.
- **TC-ROUTE-002** Health endpoints: GET `/health` (HTML) and `/v1/health` (JSON) for each host.
  Verify status, payload, cache headers.
- **TC-ROUTE-003** Host constraint enforcement: hitting `top` routes with mismatched host
  returns 404.
- **TC-ROUTE-004** Rate limit guard: simulate >1,000 requests/hour to sign/help endpoints; expect
  429 with Valkey-backed limiter.

### 7.2 Preferences & Cookies

- **TC-PREF-101** Region update: POST `/preference/region` with `lx=ja&ri=jp&tz=jst`; expect signed
  cookie update and redirect parameters normalized (lowercase codes).
- **TC-PREF-102** Invalid timezone: send unsupported value; expect flash alert with translation key
  and `422` status.
- **TC-PREF-103** Theme update: toggling to `dark` writes `root_<scope>_theme` cookie and persists
  to `root_<scope>_preferences`.
- **TC-PREF-104** Cookie consent toggles: editing `preference/cookie` stores boolean flags, default
  false.

### 7.3 Identity & Security (Sign)

- **TC-SIGN-201** Email registration happy path (Turnstile bypass in test):
  `POST /sign/.../registration/emails` -> expect session metadata, OTP mail, redirect to `edit`.
  Submitting correct OTP persists `UserIdentityEmail` and clears session.
- **TC-SIGN-202** Expired OTP: set `expires_at` in session to past time; `#update` returns 422 with
  error.
- **TC-SIGN-203** Telephone registration: invalid E.164 rejected; valid number triggers
  `AwsSmsService`.
- **TC-SIGN-204** Passkey challenge: POST `/setting/passkeys/challenge`; expect JSON options with
  challenge stored in session. Replay fails once challenge consumed.
- **TC-SIGN-205** TOTP creation: GET `/setting/totps/new` returns QR data; POST with valid token
  persists encrypted secret; invalid token re-renders with error.
- **TC-SIGN-206** JWT issuance: calling `Authn#log_in` writes `access_token` (ES256) and encrypted
  `refresh_token`; tampering with token triggers `JWT::VerificationError`.
- **TC-SIGN-207** Logout: `DELETE /sign/.../authentication` clears auth cookies and redirects to
  login.

### 7.4 Help & Contact

- **TC-HELP-301** Successful contact: POST `/help/com/contacts` with valid email, phone, policy
  consent; expect encrypted DB record and notice.
- **TC-HELP-302** Turnstile failure: stub API to return `success=false`; controller logs warning,
  adds error to form, status 422.
- **TC-HELP-303** Policy enforcement: front-end script prevents submission; server-side also rejects
  unchecked consent.
- **TC-HELP-304** OTP requirement: missing OTP fields should fail validation with error message.

### 7.5 API & BFF

- **TC-API-401** Email validation endpoint: GET `/api/app/v1/inquiry/valid_email_addresses/:id` with
  Base64 email; expect JSON body with `valid`.
- **TC-API-402** Telephone validation: POST JSON to `/api/app/v1/inquiry/valid_telephone_numbers`;
  expects `valid` key and proper status codes.
- **TC-API-403** Health JSON: `/api/*/v1/health` returns `{ status: "OK" }`.
- **TC-BFF-404** Preference email edit: hitting `/bff/app/preference/emails` retains locale/timezone
  query params normalized by the preference concerns.

### 7.6 Docs/News/Help health

- **TC-DOC-501** GET `/` on docs/news hosts returns 200 with placeholder markup and hydration
  dataset.
- **TC-DOC-502** `/health` + `/v1/health` respond for docs/news/help staff hosts.

### 7.7 Redirect & Security

- **TC-SEC-601** Redirect whitelist: generating jump token for allowed host works; unknown host
  rejected (no redirect, 404).
- **TC-SEC-602** Allow browser: spoof legacy User-Agent -> request blocked (based on `allow_browser`
  behavior).
- **TC-SEC-603** Preference cookie tampering: malformed JSON replaced with defaults; verify logs
  warn.
- **TC-SEC-604** PII encryption: retrieving `ServiceSiteContact` from DB should not expose plaintext
  values; assert encrypted columns differ from input.

### 7.8 Observability & Ops

- **TC-OBS-701** OTEL span creation: hitting `/sign` while `OTEL_EXPORTER_OTLP_ENDPOINT` is set
  emits span visible in Tempo.

---

## 8. Non-Functional Tests

| Category      | Test                                                                                                                          |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Performance   | k6 script runs 1k req/min against `/sign` and `/help` endpoints; verify p95 < 500 ms, error rate < 0.5 %.                     |
| Load          | Simulate 100 concurrent OTP submissions; ensure Valkey/Redis sizing suffices and no session collisions.                       |
| Reliability   | Restart Compose services mid-request; ensure graceful error pages and health endpoints report BOOTING vs OK.                  |
| Security      | Brakeman, Bundler Audit, RuboCop security cops; manual pen-test for JWT tampering, Turnstile bypass attempts, redirect abuse. |
| Localization  | Preferences propagate `lx`, `ri`, `tz`, `ct` through redirects; fallback defaults apply when cookies absent.                  |
| Observability | Verify health dashboards chart request rates, OTP failures, and Turnstile errors.                                             |

---

## 9. Tooling, Data, and Automation

- **Tools**: Minitest, Rswag, pnpm-run JS tests/tooling, Playwright or Capybara, k6, curl scripts,
  Postman, Brakeman, Bundler Audit.
- **Fixtures**: Stored per DB context; use `ActiveRecord::FixtureSet.create_fixtures` per database
  connection. Sensitive examples anonymized.
- **Data cleanup**: Multi-DB tests must wrap in transactions (Rails 8 multi-db test helpers) or rely
  on DatabaseCleaner configured per DB.
- **Secrets**: Tests requiring Turnstile should use test keys; OTP mailers configure `letter_opener`
  in development/test.

---

## 10. Entry / Exit Criteria

- **Entry**: Feature merged to main, migrations applied, Compose services healthy, linting passes,
  required secrets present.
- **Exit**:
  - All tests in this TS executed or justified as not applicable.
  - Critical/High defects resolved or accepted with mitigation plan.
  - Health dashboards show green and OTEL traces are present.
  - Release checklist (docs/checklist.md) signed off by Product + Engineering.

---

## 11. Maintenance

- Update this TS whenever routes, controllers, or integrations change (e.g., new namespace, new API
  endpoint, new OTP flow).
- Keep automated tests aligned with acceptance criteria and traceability matrix.
- Document manual steps for smoke/perf tests in `docs/checklist.md` or runbooks.

> Testing is everyone’s responsibility. If a feature lacks coverage here, it is not ready for
> production.
