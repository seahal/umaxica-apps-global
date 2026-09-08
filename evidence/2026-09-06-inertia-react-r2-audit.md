# Inertia Rails + React audit and Cloudflare R2 asset-delivery readiness

Date: 2026-09-06 Branch: `feature` Commit at start: `76755acb4`

Scope: audit every Rails surface that publishes browser HTML from Rails itself, confirm the Inertia
Rails + React + Vite path is real and safe, run the production asset build, and judge whether that
build output can be moved to a Cloudflare R2 custom domain.

## Environment

| Component                      | Version                               |
| ------------------------------ | ------------------------------------- |
| Ruby                           | 4.0.6                                 |
| Rails                          | 8.2.0.alpha (git, `rails/rails` main) |
| inertia_rails                  | 3.22.0                                |
| vite_rails / vite_ruby         | 3.11.1 / 3.10.5                       |
| Node                           | v24.19.0                              |
| pnpm                           | 12.0.0                                |
| vite                           | 8.2.2                                 |
| vite-plugin-ruby               | 5.2.3                                 |
| react / react-dom              | 19.2.8                                |
| @inertiajs/react / core / vite | 3.7.0                                 |
| @vitejs/plugin-react           | 6.1.1                                 |
| typescript                     | 7.0.2                                 |

Package manager is pnpm and was not changed; `pnpm-lock.yaml` was not modified. No gem or npm
version was changed by this work.

## Surfaces investigated

Determined from `config/routes/*.rb` host constraints, `lib/config_values_host_family_values.rb`,
`compose.env`, `config/environments/production.rb` host authorization, and the controller tree.
Hostnames below are quoted from the repository, not inferred.

| Surface                                   | Rails role                                    | Frontend owner                                      | Inertia expected | Inertia present                   |
| ----------------------------------------- | --------------------------------------------- | --------------------------------------------------- | ---------------- | --------------------------------- |
| `auth` app/com/org                        | credential gateway, browser HTML              | Rails                                               | yes              | yes (71 controllers)              |
| `base` app/com/org                        | identity authority, browser HTML              | Rails                                               | yes              | yes (88 controllers)              |
| `core` app/com/org/dev                    | regional BFF; only `/` is HTML                | Rails (root), Edge (public HTML)                    | root only        | yes (4 roots)                     |
| `side` app/com/org                        | control plane, browser HTML                   | Rails                                               | yes              | yes (roots, dashboards, settings) |
| `palm` app                                | native RP landing + bearer API                | Rails (landing)                                     | landing only     | yes (roots, sign-outs)            |
| `info`/`help`/`docs`/`news` × app/com/org | content read API + one thin landing card      | **Edge repo** (`umaxica-apps-edge`, TanStack Start) | **no**           | none, correctly                   |
| `base` net/dev, `core` net                | machine/control-plane, `render plain:` + JSON | n/a                                                 | no               | none                              |

The `info`, `help`, `docs` and `news` surfaces are the important classification. Their public HTML
is owned by a separate repository, not by Rails:

- `docs/architecture/content-surface-matrix.md:13-16` — "Public HTML for these surfaces belongs to
  Edge, not Rails. Current Edge runtime for the twelve content packages is TanStack Start on
  Cloudflare Workers."
- `docs/architecture/docs-help-news-content-boundary.md:15-19` — "Edge owns the public frontend for
  `docs`, `help`, `news`, `info`, and `core`."

Rails serves them only a JSON read API (`/api/v0/entries`, `PublishingContentRendering`) plus one
standalone landing card per cell rendered with `layout false`. Under the frontend policy these must
not be converted to Inertia, and they were not. Confirmed there is no Astro or TanStack code in this
repository: no `astro`/`@tanstack` dependency in `package.json`, no `astro.config.*`, no
`wrangler.*`.

## Gap found and closed: `side` settings was the one Rails-direct browser page not using Inertia

`side/{app,com,org}#settings` answered `render plain: "Settings"` from `BareController`
(`AUTHENTICATION_MODE = :bare`), while every other browser screen on the same surface — roots,
dashboards, sign-outs — is an Inertia page. It is linked from the anonymous Side landing
(`app/controllers/side/app/roots_controller.rb`), so it is a real browser destination that dropped
the surface chrome, the theme and the locale.

It is now an Inertia + React page on `Side::<Surface>::ApplicationController` with
`AUTHENTICATION_MODE = :open`, matching the roots controller it is linked from. No artificial route
was added; the existing `resource :settings, only: :show` route is unchanged.

## Changes made

| File                                                              | Reason                                                                                                                                                                                                                                      |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app/controllers/base/app/identity/secrets_controller.rb`         | HIGH: add `SignSettingsSecretCredentialCacheControl` + `before_action :set_no_store_for_secret_credential_pages`. The `new` action renders the plaintext recovery secret as an Inertia prop; without `no-store` the response was cacheable. |
| `test/controllers/base/app/identity/secrets_controller_test.rb`   | Regression test pinning `no-store` on the page that reveals the plaintext secret.                                                                                                                                                           |
| `app/controllers/concerns/side_settings_page.rb` (new)            | Props for the shared Side settings screen, mirroring `SideDashboardPage`.                                                                                                                                                                   |
| `app/controllers/side/{app,com,org}/settings_controller.rb`       | `render plain:` replaced with `render inertia:` on the surface `ApplicationController`.                                                                                                                                                     |
| `src/features/dashboards/SideSettings.tsx` (new)                  | The shared React component, built from the existing `Page` and `NavList` primitives.                                                                                                                                                        |
| `src/pages/side/{app,com,org}/settings/show.tsx` (new)            | Per-surface page module; each surface resolves only its own directory.                                                                                                                                                                      |
| `test/controllers/side/{app,com,org}/settings_controller_test.rb` | Assert component name, props, link set, and anonymous reachability.                                                                                                                                                                         |
| `vite.config.ts`                                                  | `build.sourcemap: "hidden"`. See below.                                                                                                                                                                                                     |
| `test/unit/security/skip_forgery_protection_usage_test.rb`        | Glob widened to `app/controllers/**/*.rb`; the guard could not see concerns and was passing vacuously.                                                                                                                                      |

### Source maps

`vite-plugin-ruby` sets `sourcemap: !isLocal` (`node_modules/vite-plugin-ruby/dist/index.mjs:237`),
so every production build emitted `.map` files **and** a `//# sourceMappingURL=` comment in each
chunk. Assets are served from a separate asset host, so that comment advertises the original
TypeScript — paths, comments and reasoning — to any visitor.

`build.sourcemap: "hidden"` keeps the `.map` files, which an error monitor still needs, and drops
the pointer. Verified on a clean rebuild: 0 `sourceMappingURL` comments across 50 emitted `.js`
files, 48 `.map` files still produced.

### Security guard that was passing vacuously

`test/unit/security/skip_forgery_protection_usage_test.rb` globbed
`app/controllers/**/*_controller.rb` with an empty allowlist. The only `skip_forgery_protection`
call in the repository is in `app/controllers/concerns/csp_violation_report.rb:17`, which that glob
excludes — the guard asserted `[] == []`. It now globs `app/controllers/**/*.rb` and carries that
one call site as a reviewed, documented allowlist entry, so a future concern adding the call is
visible.

## Security audit results

Audited props leakage, XSS, CSRF, authentication/authorization, cross-FQDN navigation, cookies and
CSP across 285 `render inertia:` call sites, 163 controllers including `SurfaceInertiaPage`, and all
of `src/`.

| Severity | Finding                                                                                                                                                                                                                                       | Status                        |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| HIGH     | `base/app` recovery-secret page rendered the plaintext secret into `data-page` with a cacheable response; `com`/`org` already carried `no-store`                                                                                              | fixed, test added             |
| MEDIUM   | Sign-up checkpoint passcode pages (`auth/{app,com}/sign/up/check/telephone/passcodes_controller.rb`) render a plaintext secret with no cache directive                                                                                        | not fixed — reported below    |
| MEDIUM   | One-time reveal token travels in a cross-surface URL query string; contained by single-use `IdentityOneTimeReveal.consume!` bound to actor and session nonce                                                                                  | not fixed — reported below    |
| MEDIUM   | Preference cookie is apex-scoped with `httponly: false` (`app/controllers/concerns/preference_cookie_writer.rb:12-13`); the accepted-risk note in `app/values/core_cookie_domain.rb:83-86` relies on HttpOnly, which this cookie does not set | not fixed — reported below    |
| LOW      | `skip_forgery_protection` guard could not see concerns                                                                                                                                                                                        | fixed                         |
| LOW      | `style-src`/`font-src`/`img-src` permit the bare `https:` scheme                                                                                                                                                                              | not fixed — see R2 note below |
| INFO     | `description_html` prop (`app/controllers/concerns/surface_chrome.rb:170`) is rendered as text by `CookieBanner.tsx:174`, so its markup shows literally; safe, but misnamed                                                                   | not fixed                     |

Findings with no defect:

- **XSS**: zero occurrences of `dangerouslySetInnerHTML`, `innerHTML`, `document.write`, `eval(`, or
  `new Function` in `src/`; zero `html_safe`/`raw(` in `app/views` and `app/helpers`. All 50
  `href={}` bindings trace to Rails route helpers, not user input.
- **Props**: no whole-model serialization. Every `props:` block is a hand-built allowlist. Session
  listings carry no IP or user agent.
- **Partial reloads**: zero uses of `InertiaRails.lazy`/`defer`/`optional`/`merge` and no
  `X-Inertia-Partial-Data` handling in application code, so every prop is computed inside the
  authorized action. There is no path where a partial reload skips an authorization check.
- **CSRF**: no `skip_forgery_protection` on any Inertia action. The token travels by
  `csrf_meta_tags`, not a cookie. `TrustedOriginForgeryProtection` rejects `Origin: null` and a
  missing Origin under `Sec-Fetch-Site: same-site`.
- **Cross-FQDN**: `TextLink`, `ButtonLink`, `NavList` and `Page` all default to a document visit, so
  a cross-origin destination is never an Inertia XHR. Cross-host redirects on Inertia requests are
  converted to `409 + X-Inertia-Location`
  (`app/controllers/concerns/authentication_base.rb:730-745`). No absolute `http(s)://` URL is
  hardcoded anywhere in `src/`.
- **CSP**: no `unsafe-inline` or `unsafe-eval` in any environment. `script-src` is
  `'self' 'strict-dynamic' https://challenges.cloudflare.com` plus a per-request nonce. Only
  development adds the Vite HMR `ws://`/`wss://` sources to `connect-src`; production keeps
  `connect-src` to self plus Turnstile.
- **Session cookie**: `__Host-session`, Secure, HttpOnly, `SameSite=Lax`, Partitioned, no `Domain`.

## Commands run and results

| Command                                                           | Result                                                                                                            |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `pnpm build` (`NODE_ENV=production vite build --mode production`) | success, exit 0, built in 1.73s after a clean `rm -rf public/vite`                                                |
| `pnpm test:unit`                                                  | 22 files, 281 tests, 0 failures                                                                                   |
| `pnpm test:component`                                             | **blocked** — see below                                                                                           |
| `pnpm run format:check`                                           | clean, 628 files                                                                                                  |
| `pnpm run lint` (oxlint)                                          | clean                                                                                                             |
| `pnpm run typecheck` (tsc --build)                                | clean                                                                                                             |
| `pnpm run deadcode` (knip)                                        | clean                                                                                                             |
| `bin/rubocop` on the 10 changed Ruby files                        | 0 offenses                                                                                                        |
| `bin/brakeman`                                                    | 847 controllers, 701 models, 0 errors, 2 weak-confidence SQL warnings, both pre-existing and unrelated to Inertia |
| `bin/bundler-audit check --update`                                | no vulnerabilities, advisory DB at commit `e7179ad2`                                                              |
| `pnpm audit --prod`                                               | no known vulnerabilities                                                                                          |
| `bin/rails test test/controllers` (baseline, before changes)      | 4087 runs, 25638 assertions, 0 failures, 0 errors                                                                 |

Brakeman's two warnings are `app/models/concerns/publishing/taxonomy_term_record.rb:58` and
`app/queries/publishing_published_entries_query.rb:116`; both interpolate through
`quote_table_name`/`quote` and neither is on the Inertia path.

### Check that could not be completed

`pnpm test:component` — the Vitest browser project cannot start. Playwright's Chromium is installed
but fails to launch:
`chrome-headless-shell: error while loading shared libraries: libatk-1.0.so.0: cannot open shared object file`.
The container runs as uid 1000 with no `sudo` and no package manager access, so the missing system
libraries cannot be installed here. The same limitation blocks the Playwright E2E suite. React
rendering was therefore **not** verified in a real browser in this session; it was verified through
the jsdom unit project, the Rails-side Inertia page contract, and the presence of the compiled
components in the production bundle.

## Production build output

Clean build into `public/vite/`:

- 50 `.js`, 14 `.css`, 24 `.png`, 12 `.svg`, 8 `.pdf`, 48 `.map`
- All 108 non-map assets carry a content hash in the filename; 0 unfingerprinted
- Manifests: `public/vite/.vite/manifest.json` (120 entries, 53 entrypoints) and
  `public/vite/.vite/manifest-assets.json`
- Manifest integrity checked programmatically: every `file` and every `css` entry exists on disk, 0
  missing
- All 14 Inertia entrypoints present, one per surface (`auth_{app,com,org}`, `base_{app,com,org}`,
  `core_{app,com,org,dev}`, `side_{app,com,org}`, `palm_app`)
- No origin-absolute `/vite/` URL is baked into any emitted `.js` or `.css`; the only `url()` values
  in CSS are `data:` URIs. Chunk imports are relative, so they resolve against the entry script's
  own origin.

React + Inertia verification for the newly converted screen: `side/app/settings/show` appears in the
built `side_app` entry chunk, and `SideSettings` is bundled into all three Side entries.

## Cloudflare R2 readiness: READY WITH CONFIGURATION

Nothing in the repository provisions R2, and no Cloudflare credential exists here, so no upload was
attempted. The application side is in place; what remains is Cloudflare-side configuration and a
publish step.

**Asset output directory**: `public/vite/` (`publicOutputDir` defaults to `vite`; the repo overrides
it only for development and test).

**Manifest location**: `public/vite/.vite/manifest.json` and `.vite/manifest-assets.json`.

**Upload target**: `public/vite/assets/**` except `*.map` — the 108 fingerprinted, browser-public
JS/CSS/font/image/PDF files.

**Not upload targets**:

- `public/vite/.vite/manifest*.json` — Rails resolves every entrypoint through these at request time
  (`vite_javascript_tag`). They are application metadata and belong in the application artifact. The
  `Containerfile:165-168` copy already puts them in the runtime image; that is the right home.
- `*.map` — build artifacts for a private error monitor, not browser-public assets.

**Asset host configuration**: two independent switches, both already env-driven, both must name the
same origin.

1. Request-time tag URLs: `config.asset_host` in `config/environments/production.rb:33-35`, read
   from `PUBLIC_ASSET_URL` (legacy alias `ASSET_URL`), with no literal default — a missing value
   raises at boot rather than silently serving from the wrong CDN. `compose.env:163` currently sets
   `PUBLIC_ASSET_URL=asset.umaxica.net`. Pointing this at the R2 custom domain is the whole switch
   for `<script>`, `<link rel=modulepreload>` and `<link rel=stylesheet>` hrefs, because
   `vite_asset_path` routes through Rails' `path_to_asset`.
2. Build-time baked URLs: `VITE_RUBY_ASSET_HOST`, which `vite-plugin-ruby` reads straight from
   `process.env` (`dist/index.mjs:44`, `resolveViteBase` at `:160-166`) and turns into Vite's
   `base`. It is **not set anywhere in the repository**, so `base` is currently `/vite/`.

   This is inert today — verified above that no absolute `/vite/` URL is baked into any chunk — but
   it is the latent failure. The CI job and the `Containerfile` production-assets stage both run
   `pnpm exec vite build --mode production` with no Ruby present, so `vite_rails`' automatic
   `asset_host` export never applies. The first asset referenced from CSS `url()` or from JS by
   filename would bake `/vite/assets/...`, an absolute path on the Rails origin, where
   `config.public_file_server.enabled = false` (`production.rb:257`) returns 404. Set
   `VITE_RUBY_ASSET_HOST` to the R2 custom domain in both build paths at the same time as
   `PUBLIC_ASSET_URL`.

No URL is hardcoded in source in either path.

**r2.dev**: not used and must not be. There is no `r2.dev` reference anywhere in the repository.

**CORS requirements**: the R2 custom domain is a different origin from every Rails surface. ES
module scripts are always fetched in CORS mode, and `vite_javascript_tag` additionally emits
`crossorigin` on the entry script and on every `modulepreload` link, so R2 must return
`Access-Control-Allow-Origin` for the JS, CSS and font objects or the modules will not load. Rails'
`rack-cors` is irrelevant here — it is installed but never inserted (`config/initializers/cors.rb`
is entirely commented out), and it could not add headers to responses Rails does not serve. The
allowlist belongs in the R2 bucket CORS policy and should name the browser surface origins
explicitly rather than `*`.

**CSP requirements**: no change is needed to load JS from R2. `script-src` carries
`'strict-dynamic'`, which makes browsers ignore host allowlists in that directive entirely; the
per-request nonce on the entry script and the modulepreload links is what admits them, and
`test/integration/vite_asset_nonce_test.rb` already pins that every emitted tag carries it.
`style-src`, `font-src` and `img-src` permit the bare `https:` scheme, so R2-hosted CSS, fonts and
images are already allowed — which is why tightening that scheme source (LOW finding above) needs to
happen together with naming the explicit asset origin, not before it. `connect-src` is `'self'` plus
Turnstile and does **not** include the asset host; that is correct as long as no asset is fetched by
`fetch()`/XHR, which none currently are.

**Cache policy**: every one of the 108 uploadable objects is content-hash fingerprinted, so
`Cache-Control: public, max-age=31536000, immutable` is safe for the `assets/**` prefix. It must not
be applied to anything outside that prefix; the manifests are mutable and are not uploaded at all.

**Source-map policy**: `.map` files must not be uploaded to the public bucket. With
`build.sourcemap: "hidden"` there is no longer a `sourceMappingURL` pointer, so a leaked map is no
longer discoverable from the served asset, but exclusion is still the control. If maps are wanted
for error monitoring, upload them to the monitor (Sentry is already a dependency) or to a private,
non-public-read bucket.

**Atomic deployment ordering**: filenames are content-addressed, so old and new generations coexist
without collision. The safe order is (1) build assets, (2) upload `assets/**` to R2, (3) verify the
uploaded objects resolve, (4) release the Rails image carrying the matching manifest. Because Rails
resolves URLs through a manifest baked into its own image, a release can only ever reference assets
built in the same step, so uploading before releasing removes the window where HTML names an object
R2 does not have. Do not purge old hashed objects on deploy: a rollback serves the previous image,
whose manifest names the previous hashes.

Two practical notes for whatever performs the upload:

- The Apple sign-in brand assets have spaces in their filenames (e.g.
  `Logo - SIWA - Left-aligned - Black - Large-DLVLlpUq.svg`), so the uploader must URL-encode object
  keys.
- `emptyOutDir` resolves to `false` for production builds (`vite-plugin-ruby` sets
  `emptyOutDir: ssrBuild || isLocal`), so `public/vite/assets` accumulates generations across
  repeated local builds. Build in a clean directory, or the upload set will include stale chunks.

**Inertia asset versioning**: `config.version = ViteRuby.digest`
(`config/initializers/inertia_rails.rb`). `ViteRuby.digest` is a SHA-1 over the _watched source
tree_ (`src/**/*`, lockfiles, `vite.config.ts`, `config/vite.json`), memoized for one second — not a
digest of the built manifest. The runtime image ships `src/`, so this resolves at runtime and
changes on every deploy that changes source, which is what forces a stale Inertia client to reload.
It works, but it is worth knowing that the version tracks source rather than build output.

## Remaining work

Blocked on things not available in this session, not on application code:

- Cloudflare-side: create the R2 bucket, attach a custom domain, set the bucket CORS allowlist to
  the browser surface origins, and set the `assets/**` cache rule. No Cloudflare credential exists
  here.
- A publish step. `public/vite` is built by CI (`.github/workflows/ci.yml:55-80`) and copied into
  the runtime image (`Containerfile:165-168`), but nothing uploads it. This is already recorded at
  `notes/implementation/inertia-per-surface-vite-pipeline.md:71-77`. No upload tooling was added
  here because the bucket, the credential and the deploy target do not exist yet; the seam it would
  use (`PUBLIC_ASSET_URL` + `VITE_RUBY_ASSET_HOST`, both already env-driven) is in place.
- Browser-level verification of React hydration, blocked by the missing Playwright system libraries
  described above.

Security findings left open, in priority order: the two MEDIUM plaintext-secret cache-control gaps
on the sign-up checkpoint passcode pages, the MEDIUM one-time reveal token in a query string, and
the MEDIUM `httponly: false` on the apex-scoped preference cookie. Each is described with its file
and line above.
