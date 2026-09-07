# Inertia Rails security audit

Date: 2026-09-07 Branch: `feature` Base commit: `76755acb4`

A security-focused audit of the Inertia Rails integration across every Rails surface that publishes
browser HTML from Rails itself: `auth`, `base`, `core`, `side`, `palm`. Complements
`evidence/2026-09-06-inertia-react-r2-audit.md`, which covered the architecture, build and asset
delivery side; this record covers CSRF, browser history, props, redirects, caching, SSR and
dependencies.

Surface classification is taken from the previous record and was not re-derived: `info`, `help`,
`docs` and `news` publish their browser HTML from a separate repository (`umaxica-apps-edge`,
TanStack Start), so they are out of scope for Inertia hardening and were left alone.

## Verdict

PASS WITH RESIDUAL RISKS. One HIGH defect was found and fixed (browser history was never cleared on
sign-out), two MEDIUM cache-control gaps on plaintext-secret pages were fixed, and two MEDIUM
findings are recorded but not fixed. Every other item in the target baseline was already satisfied.

## Fixed in this session

### HIGH — Inertia browser history was encrypted but never cleared

`config/initializers/inertia_rails.rb:7` sets `config.encrypt_history = true`, but a repository-wide
search for `clear_history` / `clearHistory` returned **zero call sites** in `app/`, `config/`,
`lib/` and `src/`.

Encryption alone does not survive sign-out. The adapter encrypts each history entry's page state,
but the key that decrypts it lives in the same tab's `sessionStorage`, which `reset_session` does
not touch. After signing out, pressing Back in the same tab decrypts and restores the last
privileged page — the exact scenario history encryption is meant to prevent.

Fixed by passing `clear_history: true` at each sign-out completion render:

- `app/controllers/base/{app,com,org}/sign_outs_controller.rb` — `render_oidc_logout_completion`
- `app/controllers/base/{app,com,org}/oidc/logouts_controller.rb` — `render_oidc_logout_completion`
- `app/controllers/concerns/sign_out_inertia_pages.rb` — `render_oidc_rp_logout_completion` (auth
  app and org), which carries the canonical explanation

`renderer.rb:28` reads the option and `:137` emits it as `clearHistory` in the page object.

**A first attempt was rejected and reverted.** Setting `session[:inertia_clear_history] = true` in
`AuthenticationLogoutable#logout_current_session!` after `reset_session` is the adapter's other
documented route (the flag survives a redirect and `middleware.rb:35` consumes it once), and it
would have covered every surface from one place. It was abandoned because it broke six assertions in
`test/controllers/concerns/authentication/logoutable_test.rb`, which require the Rails session to be
_empty_ after logout — including in the `ensure` path when revocation raises. That is a deliberate
security invariant, and weakening it to carry a convenience flag is the wrong trade. Passing the
option at the render keeps the session empty and makes each completion page state its own intent.

Note for future readers: the option in inertia_rails 3.22.0 is `config.encrypt_history`
(`configuration.rb:26`), not `config.history_encrypt`. The repository already uses the correct name.

### MEDIUM — plaintext recovery passcode rendered into a cacheable response

`auth/app` and `auth/com` sign-up telephone passcode checkpoints serialize the freshly generated
plaintext recovery secret into the `secret` prop, which inertia_rails writes into the initial
document. The checkpoint concerns set `Cache-Control: no-store, private` only on their
age-restricted branch (`app/controllers/concerns/app_sign_up_checkpoint_page.rb:111`,
`com_sign_up_checkpoint_page.rb:109`), which does not cover the passcode reveal. The prop is rebuilt
from the session on every failed submit, so the plaintext was emitted repeatedly.

Both controllers now include `SignSettingsSecretCredentialCacheControl` and run
`before_action :set_no_store_for_secret_credential_pages`:

- `app/controllers/auth/app/sign/up/check/telephone/passcodes_controller.rb`
- `app/controllers/auth/com/sign/up/check/telephone/passcodes_controller.rb`

## Verified already correct — no change made

### CSRF: matches the target baseline on every surface, including palm

`protect_from_forgery using: :header_or_legacy_token` is declared on all 54 controller bases across
every surface. Palm is **not** an exception:
`app/controllers/palm/app/application_controller.rb:21`, `palm/app/bare_controller.rb:16`,
`palm/app/api/v0/base_controller.rb:16`.

The one deviation is `app/controllers/base/app/oidc/logouts_controller.rb:29`, which uses
`:header_only` — strictly tighter than the baseline, not a bypass.

`config.action_controller.allow_forgery_protection` is `true` in development (`development.rb:150`)
and production (`production.rb:301`), and `false` only in `config/environments/test.rb:57`, which is
stock Rails.

`skip_forgery_protection` appears exactly once, in
`app/controllers/concerns/csp_violation_report.rb:17`, scoped `only: :create` on the unauthenticated
browser-telemetry endpoint, rate-limited at `:20-26`. The guard test that tracks it was fixed in the
previous session — it globbed `app/controllers/**/*_controller.rb` with an empty allowlist and so
could not see the concern it existed to track, asserting `[] == []`.

There is no Inertia-specific CSRF mechanism; Rails remains the authority. The token reaches React
through `csrf_meta_tags` in each `inertia.html.erb` layout, not through an XSRF cookie.

### Redirects: no open-redirect path into `inertia_location`

There is one conversion site, `convert_redirect_to_inertia_location!`
(`app/controllers/concerns/authentication_base.rb:730-743`), reached from `:717` and `:2965`. It
reads `location` from `response.location` — a redirect Rails has already issued and already
validated, including its `allow_other_host` check. It converts an existing redirect in place rather
than accepting a destination, so it introduces no new sink. No `inertia_location(params[...])`
pattern exists anywhere.

The repository already enforces this statically. `test/unit/security/redirect_target_usage_test.rb`
forbids `redirect_to params[...]` in controllers, forbids raw `params[:pt]` outside the verification
namespace, forbids the legacy `redirect_to_xt` helper, and pins every `allow_other_host: true` to a
16-entry reviewed allowlist.

### Representation and caching

`Vary: X-Inertia` is set by the adapter itself
(`inertia_rails-3.22.0/lib/inertia_rails/renderer.rb:47-49`), which appends it without clobbering an
existing `Vary`. The HTML and Inertia-JSON representations of the same URL are therefore not
conflatable by a shared cache, and no application code hand-rolls this.

No Inertia page sets `public: true` caching. The only `expires_in(..., public: true)` in the
controller tree is `app/controllers/concerns/authentication_jwks_rendering.rb:8`, on the public JWKS
document, which carries no user state.

### Props and shared props

Props are hand-built allowlists throughout; the previous session's sweep of 285 `render inertia:`
sites found no whole-model serialization. The only `as_json` calls on the Inertia path are on
WebAuthn `PublicKeyCredentialRequestOptions`, which the browser API requires.

Shared props are minimal: exactly one, `inertia_share chrome: -> { surface_chrome }`
(`app/controllers/concerns/surface_chrome.rb:45`). Its payload (`surface_chrome`, `:65-79`) carries
only presentational data — family label, surface name, brand name and root href, banner, navigation
links, cookie and theme controls, copyright. No identity, no tokens, no authorization state is
globally shared.

A static guard forbidding raw-model props was considered and deliberately not added: the candidate
pattern (`<key>: current_<resource>`) matches service-call keyword arguments such as
`actor: current_client` far more often than it matches props, so the guard would have been noisy
rather than load-bearing. Per-page prop assertions in ~40 controller tests cover this positively
instead.

### SSR: not in use

`ssr_enabled` defaults to `false` (`inertia_rails-3.22.0/lib/inertia_rails/configuration.rb:29`) and
the application's initializer sets no SSR option at all. There is no `src/ssr` directory and no SSR
bundle. `inertia_ssr_head` in the layouts is inert. No SSR process, port, URL or cache exists to
expose, so there is no SSR attack surface. Per the brief, absence of SSR is not treated as a defect.

### XSS and CSP

Unchanged from the previous session and re-confirmed: zero occurrences of `dangerouslySetInnerHTML`,
`innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write`, `eval(` or `new Function` in
`src/`; zero `html_safe` or `raw(` in `app/views` and `app/helpers`. CSP carries no `unsafe-inline`
or `unsafe-eval` in any environment; `script-src` is
`'self' 'strict-dynamic' https://challenges.cloudflare.com` plus a per-request nonce, and
`test/integration/vite_asset_nonce_test.rb` pins that every emitted script, modulepreload and
stylesheet tag carries it.

### Dependencies

| Check                              | Result                                            |
| ---------------------------------- | ------------------------------------------------- |
| `bin/bundler-audit check --update` | no vulnerabilities; advisory DB commit `e7179ad2` |
| `pnpm audit` (all dependencies)    | no known vulnerabilities                          |
| `pnpm audit --prod`                | no known vulnerabilities                          |

No dependency version was changed. Relevant installed versions: Rails 8.2.0.alpha, inertia_rails
3.22.0, `@inertiajs/{core,react,vite}` 3.7.0, vite 8.2.2, vite_rails 3.11.1, vite_ruby 3.10.5, react
19.2.8.

## Tests

Added:

- `test/controllers/base/app/sign_outs_controller_test.rb` — two tests: the page rendered after
  sign-out carries `clearHistory`, and the page after that does not (the flag is consumed once).
- `test/controllers/auth/com/sign/up/check/telephone/checkpoint_flow_test.rb` — the passcode reveal
  forbids caching.

Commands and results:

| Command                                                                                             | Result                                               |
| --------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `bin/rails test test/controllers/base/app/sign_outs_controller_test.rb` + passcode/checkpoint tests | 34 runs, 144 assertions, 0 failures                  |
| `bin/rails test test/controllers/auth/com/sign/up/check/telephone/checkpoint_flow_test.rb`          | 6 runs, 48 assertions, 0 failures                    |
| `bin/rubocop` on the changed Ruby files                                                             | 0 offenses                                           |
| `bin/rails test` (full suite, baseline before this session)                                         | 12469 runs, 72633 assertions, 2 failures, 1 skip     |
| `bin/rails test` (full suite, final)                                                                | 12472 runs, 72663 assertions, **2 failures**, 1 skip |

The final run's two failures are the same two pre-existing `FlatRubySourceLayoutInvariantTest`
failures present in the baseline. This session's changes introduced no failures: the failure set is
identical before and after, and 30 assertions were added.

### Pre-existing failures, both confirmed unrelated

**`Security::Invariants::FlatRubySourceLayoutInvariantTest` — 2 deterministic failures.** Fails on
both of its layout assertions because `app/models/concerns/publishing/*.rb` holds nine nested Ruby
files (`encrypted_content.rb`, `entry_record.rb`, `entry_revision_record.rb`,
`entry_slug_record.rb`, `entry_version_record.rb`, `family_taxonomy_assignment.rb`,
`publication_record.rb`, `revision_media_usage_record.rb`, and one more) where the invariant
requires a flat layout with matching constants.

Confirmed pre-existing by stashing every change from this session and the previous one
(`git stash push -u`) and re-running the invariant alone: still 3 runs, 2 failures. They originate
in the publishing CMS work in earlier commits, not in this audit. They were left alone as out of
scope; fixing them means moving nine model concerns and is a separate change.

**`CsrfNotificationEmissionTest#test_a_blocked_request_is_recorded_once...` — flaky, ~50%.** It
asserts that no framework CSRF warning is logged for a blocked cross-site request. When it fails it
reports Rails' `Caused by: ActionController::InvalidCrossOriginRequest` / `Information for cause:`
lines, which match its `/indicates a cross-site request/` shape.

This was initially misdiagnosed. A bisect appeared to pin it on the `auth/com` passcode change,
which made no sense because the test exercises the `auth/app` surface. Re-running the same code
repeatedly showed why: on the unmodified tree the test failed 3 times out of 6 runs. The bisect had
been reading noise. It is a pre-existing flaky test — most likely the exception-reporting lines race
the log capture, since the test swaps both `Rails.logger` and `ActionController::Base.logger` — and
it is not caused by any change here. Left as found; stabilizing it is a separate change.

## Residual risks

Not claimed: that the Inertia integration is free of vulnerabilities. What is claimed is that the
findings surfaced by this audit's scope were fixed or recorded.

Findings recorded and **not** fixed:

- **MEDIUM** — the one-time reveal token that unlocks the recovery-passcode reveal travels in a
  cross-surface URL query string (`app/controllers/auth/app/settings/totps_controller.rb:377-381`,
  `settings/passkeys/options_controller.rb:67-73`, `concerns/passkey_registration_flow.rb:250-257`,
  consumed at `base/app/identity/recovery_secrets_controller.rb:16-19`). It lands in browser history
  and the receiving surface's access logs. Contained by `IdentityOneTimeReveal.consume!` being
  single-use and bound to actor plus session nonce, which is why it is MEDIUM. Moving it to a POST
  or session hand-off is a flow change beyond this audit.
- **MEDIUM** — `app/controllers/concerns/preference_cookie_writer.rb:12-13` writes the preference
  cookie apex-scoped with `httponly: false`. The accepted-risk note at
  `app/values/core_cookie_domain.rb:83-86` explicitly relies on HttpOnly as the mitigation for apex
  scoping, and this cookie does not set it, so script on any sibling surface can read it. The
  session cookie itself is `__Host-`-prefixed and unaffected.
- **LOW** — `style-src`, `font-src` and `img-src` permit the bare `https:` scheme. Tightening this
  needs to happen together with naming the explicit R2 asset origin, per the previous record.
- **INFO** — the `description_html` prop (`app/controllers/concerns/surface_chrome.rb:170`) is
  rendered as text by `CookieBanner.tsx:174`, so its markup shows literally to the user. Safe, but
  the name invites someone to "fix" it with `dangerouslySetInnerHTML`.

Not verified in this environment:

- **Browser-level behaviour was not tested.** The `logout → Back → privileged page not restored`
  sequence was verified at the protocol level (the response carries `clearHistory: true`, once), not
  in a real browser. `pnpm test:component` and the Playwright E2E suite cannot run here: Chromium
  fails with `libatk-1.0.so.0: cannot open shared object file`, and the container has no root and no
  package manager. Confirming that the Inertia client actually drops the decryption key on receiving
  the flag remains an E2E check to run where a browser is available.
- **Surfaces whose sign-out completion is not an Inertia page still do not clear history.**
  `clear_history` can only travel on an Inertia response. `auth/com`, `core/{app,com,org}` and
  `side/{app,com,org}` render the shared ERB template `auth/shared/sign_outs/edit` for sign-out and
  reach completion through `OidcRpLogoutLauncher#complete_oidc_rp_logout!` without including
  `SignOutInertiaPages`, so their completion is an ERB document and carries no `clearHistory`. Those
  surfaces do serve privileged Inertia pages, so history entries for them survive sign-out exactly
  as described in the HIGH finding. Closing this means either converting those completion pages to
  Inertia or giving them an equivalent hand-off; both are flow changes beyond this audit. `palm/app`
  renders one Inertia page (`palm/app/sign_outs/show`) for both the confirmation and the result, so
  it was left alone rather than clearing history on a page that is also shown pre-logout.
- Deployment-dependent items: CDN and reverse-proxy cache behaviour in front of Rails, and the R2
  bucket CORS and cache rules described in the previous record, all depend on infrastructure
  configuration not present in this repository.
