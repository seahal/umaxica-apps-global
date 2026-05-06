# High-Level Design Document (HLD)

## Project: Umaxica App (JIT)

### Conforms to ISO/IEC/IEEE 42010:2011 and IEEE 1016:2009

---

## 1. Introduction

### 1.1 Purpose

This document expresses the architecture of the Rails-based Umaxica App (JIT) platform. It maps the
SRS requirements to components, patterns, and deployment views that keep every public Umaxica
host—marketing, authentication, docs/news, help/support, BFF, and API—consistent and operable.

### 1.2 Scope

- Rails application located at `/home/mslo/ghq/github.com/seahal/umaxica-app-jit`
- Namespaced controllers for `Top`, `Sign`, `Help`, `Docs`, `News`, `Bff`, and `Api` surfaces
- Turbo/React front-end with pnpm-managed tooling (`app/javascript/**`)
- Multi-database Active Record setup (identity, guest, universal, token, etc.)
- Supporting infrastructure: PostgreSQL primary/replica pairs, Valkey, MinIO, Grafana/Loki/Tempo
- CI/CD automation (GitHub Actions, Lefthook) and local workflows (Foreman + Docker Compose)

### 1.3 References

- `docs/srs.md`
- `compose.yml`, `Procfile.dev`
- `README.md`, `docs/checklist.md`
- Ruby on Rails Guides, ISO/IEC/IEEE 42010 & IEEE 1016

---

## 2. Design Overview

### 2.1 Objectives

1. Provide a single Rails application that can answer for dozens of hostnames defined by environment
   variables without code duplication.
2. Protect user data by routing each data class to its own PostgreSQL cluster and encrypting
   sensitive columns.
3. Deliver modern identity experiences (passkeys, OTP, OAuth, JWT) and customer-support tooling
   while keeping UX cohesive through pnpm-managed JS tooling.
4. Operate reliably through strong observability (OpenTelemetry → Tempo, logs → Loki, dashboards →
   Grafana), rate limiting, and bot mitigation (Cloudflare Turnstile).
5. Keep developer ergonomics high via Compose-based infrastructure, Foreman-managed processes, and
   pnpm + Tailwind-driven assets.

### 2.2 Principles

- **Namespace isolation**: Each host maps to a dedicated controller namespace; shared logic lives in
  concerns (`Authn`, `PreferenceRegions`, `Theme`, `Redirect`, etc.).
- **Configuration through ENV**: Hosts (e.g., `TOP_CORPORATE_URL`), downstream targets (`EDGE_*`),
  DB URLs, and secrets are injected via ENV to keep the code portable.
- **Defense in depth**: Signed cookies, JWTs, Turnstile, rate limiting, encryption, and
  `allow_browser versions: :modern` guard every entry point.
- **Observability-first**: All HTTP, Redis, and ActionMailer operations are instrumented;
  `/health` + `/v1/health` exist for every host.
- **Composable tooling**: pnpm-managed JavaScript tooling (Biome), Tailwind CLI for CSS, Foreman +
  Docker Compose for orchestration, GitHub Actions for CI.

### 2.3 Constraints

- Ruby 3.4.7 / Rails 8.x
- pnpm 10+ / Node 20+ for JavaScript tooling (no Vite/Webpacker)
- PostgreSQL 18 primaries/replicas per logical database
- Valkey for caching/rate limiting
- Cloudflare/ Fastly handle TLS and CDN duties

---

## 3. Architecture Overview

### 3.1 Context (textual diagram)

```
Browsers / Mobile Apps
    │ HTTPS via Fastly / Cloudflare
    ▼
Rails 8 Monolith (Top / Sign / Help / Docs / News / API / BFF)
    │ ├─ Postgres clusters (identity, guest, universal, profile, token, etc.)
    │ ├─ Valkey (sessions, rate limiting, Memorize cache)
    │ ├─ ActionMailer + SMTP / AwsSmsService
    │ └─ OpenTelemetry exporter (Tempo) + Loki logging
Downstream: Google Cloud (Run/Build/Storage), Cloudflare R2, Fastly CDN
```

### 3.2 Host / Namespace matrix

| Namespace            | Host variables                                          | Responsibilities                                                                                                           |
| -------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `Top::Com/App/Org`   | `TOP_CORPORATE_URL`, `TOP_SERVICE_URL`, `TOP_STAFF_URL` | Redirect to `EDGE_*` hosts, render `/health` & `/v1/health`, expose preference UIs (`cookie`, `region`, `theme`, `reset`). |
| `Auth::App/Org`      | `ID_SERVICE_URL`, `ID_STAFF_URL`                        | Registration (email/phone), authentication, passkeys, OAuth, recovery, withdrawal.                                         |
| `Help::Com/App/Org`  | `HELP_*`                                                | Contact forms with Turnstile, OTP validation, email/SMS confirmation, success receipts.                                    |
| `Docs::*`, `News::*` | `DOCS_*`, `NEWS_*`                                      | Documentation and newsroom placeholders with branded health endpoints.                                                     |
| `Bff::*`             | `BFF_*`                                                 | Preference APIs for non-authenticated clients (email/locale endpoints).                                                    |
| `Api::*`             | `API_*`                                                 | JSON endpoints (`/v1/health`, `/v1/inquiry/valid_email_addresses`, `/v1/inquiry/valid_telephone_numbers`).                 |

Routes live in `config/routes/*.rb`; the main `config/routes.rb` `draw`s each fragment to keep
concerns scoped.

### 3.3 Layered components

1. **Presentation**: ActionController namespaces + Turbo/React bundles. Entry file
   `app/javascript/application.js` imports per-surface view scripts (e.g.,
   `views/sign/app/application.ts`, `views/passkey.js`). Layouts load compiled bundles from
   `app/assets/builds`.
2. **Domain Logic**: Concerns handle cross-cutting rules (auth, region, theme, cookie consent,
   Turnstile, rate limiting, redirect sanitization). Models inherit from base records
   (`IdentitiesRecord`, `GuestRecord`, etc.) to target specific DB clusters. Services (e.g.,
   `AwsSmsService`, `AccountService`) encapsulate integration logic.
3. **Integration**: ActionMailer namespaces, Sms providers, Active Storage/Shrine, OpenTelemetry
   instrumentation, Redis/Valkey caching, external CDNs/cloud providers.

---

## 4. Module Views

### 4.1 Top (marketing & preferences)

- `Top::*::RootsController` redirects to `EDGE_*` hostnames with `allow_other_host: true`.
- `Preference::RegionController` uses `PreferenceRegions` to normalize `lx` (language), `ri`
  (region), `tz` (timezone) and persists values to signed cookies (`__Secure-root_app_preferences`)
  plus session.
- `Preference::ThemeController` leverages the `Theme` concern to restrict themes to
  `system/dark/light`, map shorthand codes, and update preference cookies.
- `Preference::CookieController` (`Cookie` concern) captures ePrivacy choices, storing
  `accept_*_cookies` flags as signed, permanent cookies.
- Views can hydrate React micro front-ends defined in `app/javascript/views/www/**`.

### 4.2 Sign (identity & security)

- Registration flow (`Sign::App::Registration::EmailsController`) resets session, validates
  Turnstile, issues HOTP tokens (ROTP), stores metadata in `session[:user_email_registration]`, and
  sends OTP with `Email::App::RegistrationMailer`.
- Telephone registration mirrors email and uses `AwsSmsService`.
- Authentication controllers set up JWT access/refresh cookies using the `Authn` concern
  (`generate_access_token`, `log_in`, `log_out`, `logged_in?`).
- Passkey endpoints (`Sign::App::Setting::PasskeysController`) expose `/setting/passkeys/challenge`
  and `/setting/passkeys/verify`, storing challenges in session and credentials in `UserPasskey`.
- TOTP settings (`Sign::App::Setting::TotpsController`) create QR codes via `RQRCode`, persist
  encrypted secrets in `TimeBasedOneTimePassword`, and verify initial codes.
- OAuth placeholders (`Authentication::Apple/Google`) rely on OmniAuth gems and must be hardened to
  GET-only flows (tracked TODO).
- `allow_browser versions: :modern` ensures unsupported browsers fail early.

### 4.3 Help (contact center)

- `Help::Com::ContactsController` builds `ServiceSiteContact` records (inherits from `GuestRecord`).
  The model encrypts email/phone/title/description, enforces validation, and guarantees either email
  or phone exists.
- Turnstile result is logged; failures add model errors and re-render the form.
- On success, controller redirects to `new` after immediate email notification handling.
- Client-side guard (`app/javascript/views/www/app/inquiry/before_submit.js`) prevents submission
  when policy checkbox unchecked.

### 4.4 Docs & News

- Each namespace exposes `root`, `/health`, `/v1/health` with host constraints; upcoming roadmap
  will hydrate documentation/newsroom content via React views (see `app/javascript/views/docs/**`
  and `views/news/**`).

### 4.5 API & BFF

- APIs provide JSON health plus inquiry validation. `ValidEmailAddressesController` decodes Base64
  `id`, reuses `ServiceSiteContact` validations, and responds with `{valid: true|false}`.
  `ValidTelephoneNumbersController` takes JSON POST.
- BFF controllers rely on the preference concerns to normalize query params and set locale/timezone
  before rendering preference views.
- All API/BFF routes use `ActionController::API` base classes for lean responses.
- 認証モデルは責務を分離する。BFF経由の通常WebはCSRF対策と運用容易性を優先してCookieセッションを採用し、iOSなどネイティブはBearer(JWT)を採用する。両方式の同居は可能だが、同一クライアントで二重管理しない。

### 4.6 Background services

- `AwsSmsService` handles SMS dispatch for OTP-related flows.
- `Memorize` concern wraps a Redis pool with per-session prefixes and encryption for ephemeral
  key/value storage.

---

## 5. Data View

### 5.1 Multi-database layout

| Base class                                                   | Databases                                              | Representative tables                                       |
| ------------------------------------------------------------ | ------------------------------------------------------ | ----------------------------------------------------------- |
| `IdentitiesRecord`                                           | `identity`, `identity_replica`                         | `users`, `staffs`, `user_passkeys`, `user_sessions`         |
| `GuestRecord`                                                | `guest`, `guest_replica`                               | `service_site_contacts`, `corporate_site_contacts`          |
| `OccurrenceRecord`                                           | `occurrence`, `occurrence_replica`                     | `time_based_one_time_passwords`, `occurrence_*_identifiers` |
| `TokensRecord`                                               | `token`, `token_replica`                               | `user_tokens`, `staff_tokens`, `user_sessions`              |
| `BusinessesRecord`, `ProfilesRecord`, `StoragesRecord`, etc. | `business`, `profile`, `storage`, `notification`, etc. | Owners/customers/timeline data (future modules)             |

Migrations are split into `db/<context>_migrate`. UUID v7 IDs are generated (`SetId` concern).
Sensitive columns leverage Active Record encryption.

### 5.2 Caching & rate limiting

- SolidCache + Valkey for Rails caching.
- `RateLimit` concern configures `ActiveSupport::Cache::RedisCacheStore` (URL from credentials) to
  allow 1,000 req/hour per client by default.
- `DefaultUrlOptions` reads signed preference cookies (`__Secure-root_app_preferences`) to append
  `lx/ri/tz` query params automatically.
- `Memorize` stores short-lived encrypted values keyed by host + session.

---

## 6. Deployment View

### 6.1 Local development

- `compose.yml` launches: Postgres primaries/replicas for each logical DB, Valkey, MinIO, Loki,
  Tempo, Grafana. Ports default to `5435-5436` (Postgres), `56379` (Valkey), `9000/9001` (MinIO),
  `33100/3200/4317` (observability), `8000` (Grafana).
- `Procfile.dev` runs Rails server and supporting local processes; `foreman start -f Procfile.dev`
  orchestrates them. JavaScript tooling (Biome) runs via pnpm when linting/formatting.

### 6.2 CI/CD

- GitHub Actions workflow (`integration.yml`) executes bundler install, `bin/rails test`, pnpm-based
  lint/format (`pnpm run check`), RuboCop, ERB lint, Brakeman, Bundler Audit as configured by
  `lefthook.yml`.
- Deployment target (Cloud Run/Cloud Build + Fastly/Cloudflare) consumes container images or build
  artifacts; secrets injected per environment.

### 6.3 Production / staging

- Rails app runs behind Fastly/Cloudflare; TLS handled at edge.
- Google Cloud services (Cloud Run, Cloud Build, Artifact Registry, Cloud Storage) provide runtime
  and artifact storage per README.
- Cloudflare R2 + Fastly deliver static assets.
- Observability stack may point to managed Grafana/Tempo in upper environments.

---

## 7. Security & Compliance View

- **Authentication/Authorization**: `Authn` concern issues ES256 JWTs (15 min) + encrypted refresh
  tokens (1 year). Pundit is included for future fine-grained policies.
- **Bot & abuse protection**: Cloudflare Turnstile enforced on registration/contact flows;
  `RateLimit` prevents abuse; `allow_browser versions: :modern` blocks outdated clients.
- **Data protection**: Active Record encryption (deterministic where needed) shields
  email/phone/title/description fields; OTP secrets stored encrypted; preference cookies
  signed/HTTP-only.
- **Multi-factor methods**: WebAuthn (passkeys) and ROTP (TOTP/HOTP) available; `AwsSmsService` +
  email OTP support fallback.
- **Redirect safety**: `Redirect::ALLOWED_HOSTS` enumerates permitted targets; Base64-encoded jump
  tokens validated before allowing cross-host redirects.
- **Secrets**: Rails credentials store JWT keys, Cloudflare Turnstile secrets, Redis URLs, AWS keys,
  SMTP secrets. Compose `.env` wiring required for local runs.
- **Logging & auditing**: Rails logs feed Loki; OTEL traces capture request IDs and hostnames for
  auditability.

---

## 8. External Interfaces

| Interface      | Type          | Description                                                                                                                                 |
| -------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| HTTP           | REST          | Host-scoped routes for top/sign/help/docs/news/api/bff, including `/health`, `/v1/health`, `/sign/...`, `/help/...`, `/api/v1/inquiry/...`. |
| Mail           | SMTP / API    | `Email::App/Com/Org::*Mailer` deliver OTPs, contact confirmations, receipts (SES/Twilio SendGrid as configured).                            |
| SMS            | HTTPS         | `AwsSmsService` sends OTP codes.                                                                                                            |
| Redis/Valkey   | RESP          | Sessions, rate limiting, Memorize store.                                                                                                    |
| OTLP           | HTTP/gRPC     | OpenTelemetry exporter pushes spans to Tempo (`http://tempo:4318/v1/traces`).                                                               |
| Object storage | S3-compatible | MinIO (dev) / Google Cloud Storage (prod) for uploads.                                                                                      |

---

## 9. Observability & Operations

- `config/initializers/opentelemetry.rb` configures service names (`umaxica-app-jit-core`) and
  instrumentation; production enables `use_all`.
- Compose-provisioned Loki/Tempo/Grafana host logs/traces locally; dashboards highlight request rate
  and OTP/passkey errors.
- Health endpoints per host feed edge monitors and CI smoke tests.
- Future: integrate alerting (PagerDuty/Grafana Cloud) for Turnstile error spikes beyond thresholds.

---

## 10. Rationale & Future Enhancements

- **Rails vs. edge micro-apps**: consolidates duplicated auth/contact logic and simplifies
  compliance (single codebase, single observability stack).
- **Multi-database**: isolates PII domains and supports region-specific scaling (read replicas).
- **pnpm + Turbo**: avoids Webpacker/Vite overhead while keeping JS modern through lightweight
  tooling.
- **Compose-based infrastructure**: developers get a self-contained environment (Postgres, Valkey,
  observability) without external services.

**Planned enhancements**

1. Flesh out staff/admin CRUD for docs/news/help content and owner/customer management.
2. Implement real policy checks via Pundit and finish auth helper methods (`am_i_user?`, etc.).
3. Publish OpenAPI docs with Rswag for API namespaces and mount `/api-docs` when ready.
4. Automate Fastly cache purges via `fastly` gem upon content updates.
5. Expand geolocation- or cookie-based personalization once privacy review passes.

---

## 11. Appendices

- Sequence diagrams and state flows live in `docs/uml/` (to be updated alongside DDS).
- Environment variable catalog referenced in `.env.example` (future addition).
- Testing strategy captured in `docs/test.md`.
