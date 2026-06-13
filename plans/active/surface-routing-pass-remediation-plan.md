# Plan: Remediation for the Acme/Sign/Core/Base/Palm/Help/Docs/News Routing-Surface Pass

## Context

The routing/controller pass that introduced **Base, Palm, Help, Docs, News** (each app/com/org) is
implemented and committed. A static audit (no tests run) found the core scaffolding coherent and
fully resolvable (routes → controllers → concerns → models → views → DB tables), but with gaps. The
HEAD commit is self-labelled `[CheckPoint] ....... with having some bugs`, and the working tree
currently holds a large **in-flight, uncommitted health-contract refactor (~127 files)**.

This plan is for a **separate implementing agent**. It does **not** re-do the content-surface
implementation (owned by `plans/active/docs-news-help-content-surface-reimplementation-plan.md`) and
does **not** revert the Help/Docs/News content expansion — that expansion is authoritative per
`adr/read-only-content-surfaces-in-rails.md` (Accepted 2026-06-13).

Three remediation streams were selected:

1. Add tests for the new surfaces.
2. Verify the in-flight health refactor is consistent.
3. Handle the audited contradictions (Help/Docs/News OIDC RP entries; `SIGN_ISSUERS`).

### Current-state snapshot (audit evidence)

- `config/routes.rb` draws `base, palm, help, docs, news`; route files exist under `config/routes/`.
- Per variant: `bare_controller.rb` (`< ActionController::Base`), `roots_controller.rb`
  (`< <Surface>::<Variant>::BareController`), `health_controller.rb` +
  `health/{liveness,readiness,startup}_controller.rb`, `robots_controller.rb`. Help/Docs/News
  additionally have `entries_controller.rb` + `edge/v0/entries_controller.rb`.
- Base/Palm roots `render plain:` (no DB/session). Help/Docs/News roots use
  `ReadOnlyContentRendering#render_content_index` (DB-backed; ADR-authorized).
- All referenced building blocks resolve: concerns
  `app/controllers/concerns/{read_only_content_rendering,health_check_rendering,robots,rate_limit}.rb`;
  models `app/models/{help,docs,news}/{app,com,org}/content_entry.rb` (←
  `AppRpRecord`/`ComRpRecord`/`OrgRpRecord`); scopes/`as_public_json` in
  `app/models/concerns/read_only_content_entry.rb`; views
  `app/views/shared/content_entries/{index,show}.html.erb`.
- Migrations exist:
  `db/{app,com,org}_zenith_migrate/20260613000001_create_read_only_content_entries.rb`; tables
  `{docs,help,news}_content_entries` present in the `*_zenith` structure dumps. **No new DB.**
- Inheritance invariant test passes by construction (all new controllers inherit `BareController`).
- Existing Acme/Sign/Core **roots are untouched** (verified).

---

## Stream 1 — Tests for the new surfaces (REQUIRED; AGENTS.md)

No tests exist for `base/palm/help/docs/news` (`test/controllers/{base,palm,help,docs,news}/` are
empty).

### 1a. Roots

- Base/Palm (all 3 variants): integration test mirroring
  `test/controllers/acme/app/roots_controller_test.rb` but for a **plain** body:
  `host! ENV.fetch("BASE_SERVICE_URL", "base.app.localhost")`, `get base_app_root_url`,
  `assert_response :success`, `assert_equal "<exact plain message>", response.body`, and assert
  **no** session/preference cookie is set (proves no ApplicationController pipeline).
- Help/Docs/News roots: `assert_response :success`; HTML index renders
  `shared/content_entries/index`. Requires content fixtures (see 1d).

### 1b. Health (coordinate with Stream 2 — target the NEW contract)

- Per surface × variant: `get …_health_url`, `…_health_liveness_url`, `…_health_readiness_url`,
  `…_health_startup_url` → `assert_response :success` and assert the JSON/probe shape produced by
  `HealthCheckRendering#render_probe`/`#render_snapshot`. Use the profile-appropriate expectations
  (`Health::Profiles::{App,Com,Org}` for base/palm/help/docs/news).

### 1c. Robots

- Per surface × variant: `get …_robot_url` → `200`, `Content-Type: text/plain`, body equals the
  shared `::Robots` allow-all policy (`"User-agent: *\nDisallow:\n"`).

### 1d. Entries (Help/Docs/News only) + fixtures

- HTML `index`/`show` and `edge/v0` JSON `index`/`show`.
- **Fixtures are missing and non-trivial:** models are namespaced (`Help::App::ContentEntry`) on
  custom tables (`help_content_entries`) in `*_zenith` DBs. Add fixtures with explicit
  `set_fixture_class` mapping, rows that satisfy the `published` scope (`status: "published"`,
  `published_at` in the past) and `for_locale` (e.g. `locale: "ja"`/`"en"`), and assert `show` 404s
  on unpublished/wrong-locale/unknown `slug` (`find_by!` → `RecordNotFound`).

### 1e. Host/CI wiring (blocking for all of the above)

- New `*.localhost` hosts (`base/palm/help/docs/news . {app,com,org}.localhost`) and the
  `BASE_*`/`PALM_*`/`HELP_*`/`DOCS_*`/`NEWS_*` `_SERVICE_URL`/`_CORPORATE_URL`/`_STAFF_URL` ENV must
  be reachable in test/CI, or every request 404s on the host constraint. Cross-ref risk **M3** in
  `plans/active/docs-news-help-content-surface-reimplementation-plan.md`.

**Do not** add `assert true`/placeholder/skipped tests, and do not mock away the rendered behavior.

---

## Stream 2 — In-flight health refactor consistency (verify before relying on Stream 1b)

The tree migrates **all** surfaces' health controllers to `HealthController` +
`HealthCheckRendering`

- `Health::Profiles::*` and **deletes** `app/controllers/concerns/health/check_rendering.rb`.

* **Uniformity:** every surface/variant (acme app/com/org/net/dev, sign app/com/org, core, base,
  palm, help, docs, news) uses `HealthController` (singular) wired via
  `resource :health, controller: "health"` and the namespaced
  `Health::{Liveness,Readiness,Startup}Controller`. Confirm profile mapping is right (sign →
  `SignApp/SignCom/SignOrg`; others → `App/Com/Org`; decide whether `core` should keep `App/Com/Org`
  or get Core-specific profiles — flag, don't guess).
* **No dangling refs** to the deleted concern (`Health::CheckRendering` / `health/check_rendering`)
  or to the old `HealthsController`/`HealthEndpoint` from routes, controllers, or tests. (Audit
  found none currently — re-verify after the refactor settles.)
* **Test-name drift:** old `test/controllers/**/healths_controller_test.rb` (e.g. acme/com,
  acme/org, sign/\*, top-level `acme/healths_controller_test.rb`) coexist with new
  `health_controller_test.rb` (acme/app). Reconcile to one naming and the new contract; keep
  `test/integration/{health_check,health_endpoints,edge_health_routes}_test.rb` green.
* **Docs:** `docs/reference/health-endpoints.md`, `docs/operations/health-check.md`, and
  `notes/implementation/2026-06-13-health-endpoint-contract-redesign.md` must match the final
  contract.
* Commit the ~127-file refactor coherently (separately from the new-surface scaffolding if
  practical).

---

## Stream 3 — Contradictions: resolve by documenting intent (no auth-integration changes)

Per repo-owner direction, **both items are resolved by recording intent, not by code
removal/refactor.**

### 3a. Surface-boundary intent is transitional — record it in an ADR (then the OIDC entries are not a contradiction)

The Help/Docs/News (and Core/Base/Palm) OIDC client entries in
`app/services/oidc_client_registry.rb:163-244` are **transitional artifacts of a deliberately
multi-surface Rails repo**, not a silent contradiction. Capture the boundary intent explicitly:

- **Add/extend an ADR** (new `adr/transitional-rails-surface-boundary.md`, or amend
  `adr/acme-sign-core-base-port-boundary.md`) stating:
  - **Long-term target:** this Rails repository hosts **only Acme + Sign** (two surfaces).
  - **Short-term (current):** for development ease the repo co-locates **Acme + Sign + Core + Base +
    Palm + Help + Docs + News**; these non-Acme/Sign surfaces are expected to split to the regional
    side later.
  - Do **not** hard-code final repository/host/deployment boundaries now; treat the current Rails
    implementation as transitional (consistent with the original pass brief).
- Under that policy, **keep** the `docs_*`/`news_*`/`help_*` (and `core_*`) client entries, but add
  a comment marking them transitional and **not the long-term target**, and revisit at the split.
  - Note: per `adr/read-only-content-surfaces-in-rails.md`, read-only Help/Docs/News do **not**
    exercise OIDC callbacks today, so their client entries are **dormant** short-term — keep them
    labelled as such rather than deleting.
- This supersedes the earlier "recommend remove" framing. The remediation is the ADR statement; no
  registry deletion this pass.

### 3b. `SIGN_ISSUERS = "https://id.umaxica.*"` is correct by design — document, don't refactor

Repo-owner confirmed: for WebAuthn/passkey ceremonies the relying party **is** Sign's `id.umaxica.*`
(RP ID/origin is URL-bound; see memory `step-up-webauthn-url-binding`), so Sign being the
**ceremony** issuer is intended — this is **not** Sign acting as an Acme IdP/token authority. **This
is not a contradiction to fix.** Action is documentation + a light guard only:

- Add a clarifying comment in each `app/services/identity_*_ceremony_contract.rb` stating
  `SIGN_ISSUERS` are **Sign-scoped, ceremony-only** issuers, distinct from Acme access/ID-token
  issuance, so future audits don't re-flag it.
- Per-type accuracy (skeptical note): the WebAuthn URL-binding rationale cleanly covers
  passkey/step-up; for the non-WebAuthn ceremony contracts (email/telephone/social/secret/totp) the
  correct rationale is "Sign-scoped intermediate ceremony token, not Acme issuance" — phrase each
  comment to match its ceremony type rather than citing WebAuthn everywhere.
- Add/confirm a regression guard asserting Sign is **not** used as an Acme-style access/ID-token
  issuer (the boundary that must stay true), while ceremony `iss = id.umaxica.*` remains allowed.
- **No refactor** to Acme issuers.

---

## Files that should NOT be changed

- Existing `acme/*`, `sign/*`, `core/*` **roots** and their surface `ApplicationController`s.
- No new databases (`config/database.yml`); content entries stay on `*_zenith`.
- Do not revert Help/Docs/News to plain placeholders (ADR-accepted content surfaces).
- Do not implement Acme OIDC/RP integration, Palm native auth, Next.js, Cloudflare Tunnel, or
  redirects in this remediation.

## Verification (run after implementation; static checks listed first)

- `bin/rails routes | grep -E 'base|palm|help|docs|news'` — new roots/health/robots/entries present.
- `rg -n "HealthsController|Health::CheckRendering|health/check_rendering|HealthEndpoint" app config test`
  → expect none.
- 3a: confirm the transitional-boundary ADR exists and the `docs_*`/`news_*`/`help_*`/`core_*`
  entries carry a "transitional, not long-term" comment (entries are **kept**, not deleted).
- `bin/rails db:verify_no_schema_drift` — content-entries migrations vs `*_zenith` dumps agree.
- Tests (when allowed to run): new `test/controllers/{base,palm,help,docs,news}/**`,
  `controller_inheritance_invariant_test.rb`, and the health integration tests.

## Related

- `adr/read-only-content-surfaces-in-rails.md`
- `plans/active/docs-news-help-content-surface-reimplementation-plan.md`
- `plans/active/surface-routing-controller-pass-base-palm-help-docs-news.md` (the original pass
  plan)
- `notes/implementation/2026-06-13-health-endpoint-contract-redesign.md`
