# Unified Sign-Out Ceremony Redesign (Acme / Sign / Core / Base / Palm)

## Context

Recent Acme sign-out changes mixed the **human-facing sign-out ceremony** with the **OIDC
RP-Initiated Logout protocol**. The result is a fragile flow:

```
/sign/out/edit  ->  /oidc/logout?id_token_hint=...  ->  /sign/out/edit?sot=...
```

Acme local sign-out treats _itself_ as an OIDC RP (mints an `id_token_hint` via the `base-rails-rp`
client and self-redirects to `/oidc/logout`). Completion is shown at `/sign/out/edit?sot=` with a
URL-bound token, which produces stale completion URLs and a JSON `422` ("logout completion is
stale") for normal browsers. Nav buttons are inconsistent: `acme/app` links to the ceremony, but
`acme/org` and `acme/com` `button_to` straight at `/oidc/logout`.

Goal: a single user-facing ceremony (`/sign/out/new|edit|create|complete`) on every browser surface,
with `/oidc/logout` reserved strictly as the OIDC end-session protocol endpoint (Acme only). Acme
does **direct authority logout**; Sign/Core/Base are **RP launchers** that redirect to Acme
`/oidc/logout`; Palm is a future native client whose contract we only document now.

**Confirmed decisions (this session):**

1. Supersede ADR `logout-completion-boundary.md`: completion is per-surface `/sign/out/complete` on
   the _same_ surface; no cross-surface acme->sign `/signed-out` redirect. app/com/org independent.
2. Acme `/oidc/logout` reuses the shared `/sign/out/edit` confirmation (after protocol +
   redirect-URI validation) instead of its own protocol confirmation page.
3. `/sign/out/complete` is driven by the **session-bound** one-time marker
   (`SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY`), not a `sot` URL token. Stale/refreshed completion
   fails closed to friendly HTML — never JSON 422.
4. Hard cut `DELETE /sign/out` -> `POST /sign/out`. Route contract tests assert `DELETE /sign/out`
   is not recognized.

> Required reading already consulted: `AGENTS.md`, `adr/logout-completion-boundary.md`,
> `adr/logout-primitive-and-composition.md`, `adr/sign-residual-idp-surface-retirement.md`,
> `adr/acme-session-and-token-authority.md`, `docs/security/logout-sequence.md`,
> `docs/security/oidc-discovery-profile.md`, `plans/rails-log-peppy-harp.md`,
> `notes/implementation/2026-06-14-logout-boundary-realignment.md`.

---

## 1. Current-state findings (file paths)

### Routes

- `config/routes/acme.rb` — per surface:
  `namespace :oidc { resource :logout, only: %i(show create) }` (GET/POST `/oidc/logout`) and
  `scope path: :sign, module: :sign { resource :out, only: %i(new edit destroy), as: :sign_out }` →
  `GET /sign/out/new`, `GET /sign/out/edit`, `DELETE /sign/out`. **No `POST /sign/out`, no
  `/sign/out/complete`.**
- `config/routes/sign.rb` — App: `GET/POST /sign/out` (`show`/`create`); Com/Org: `GET /sign/out`
  (`show` only). RP OIDC + `POST /oidc/backchannel/logout` via
  `SignRouteMapper#sign_rp_oidc_routes`.
- `config/routes/core.rb` / `config/routes/base.rb` — `GET/POST /sign/out` per surface; Core has
  `POST /oidc/backchannel/logout`.
- `config/sign_route_mapper.rb` — NEW untracked mapper (moved out of the deleted initializer).
  Defines `sign_routes`, `sign_surface`, `sign_public_gateway_routes`, `sign_rp_oidc_routes`,
  `sign_app_social_routes`. Backchannel receiver is wired here at `oidc/backchannel/logout`.

### Controllers

- `app/controllers/acme/{app,com,org}/sign/outs_controller.rb` — `new` (redirect to edit), `edit`
  (confirmation OR completion if `sot` present), `destroy` (**self-redirects to `/oidc/logout` with
  `id_token_hint` via `base-rails-rp`** — `acme/app/sign/outs_controller.rb:28-54`).
- `app/controllers/acme/{app,com,org}/oidc/logouts_controller.rb` — thin; include `SignOidcLogout`.
- `app/controllers/concerns/sign_oidc_logout.rb` — the protocol engine.
  `perform_oidc_end_session_logout` revokes session, issues `sot`, notifies RPs, then redirects to
  `post_logout_redirect_uri` or to `oidc_logout_completed_path(sot:)` (= `/sign/out/edit?sot=`).
  `render_oidc_end_session_failure` returns **JSON 422** for stale completion
  (`sign_oidc_logout.rb:75-78`). `logout_oidc_current_session!` calls `reset_session` (`:120`).
- `app/controllers/concerns/sign_out_notice.rb` — `sot` issue/consume; param `:sot`; 5-min TTL;
  **already has `SIGN_OUT_NOTICE_SESSION_KEY`** (session-bound path) and
  `sign_out_notice_cache_headers!`.
- `app/controllers/concerns/authentication_logoutable.rb` — `logout_current_session!` (primitive,
  current session only) vs `logout_all_sessions_for!` (explicit).
- `app/controllers/{sign,core,base}/**/sign_outs_controller.rb` (+
  `sign/**/sign/outs_controller.rb`) — RP launchers: `logout_current_session!` then redirect to Acme
  `/oidc/logout` with `id_token_hint`, `post_logout_redirect_uri: <rp>_root_url`, `ri`.
- `app/controllers/concerns/oidc_rp_logout.rb`, `oidc_rp_logout_receiver.rb` — RP-side helpers.
- `app/controllers/**/oidc/backchannel/logouts_controller.rb` — `OidcRpLogoutReceiver`,
  `protect_from_forgery with: :null_session`, decodes `logout_token`, calls `OidcRpSessionLogout`.

### Views / nav

- `app/views/layouts/acme/app/application.html.erb:25-28` — logout → `new_acme_app_sign_out_path`
  (GOOD).
- `app/views/layouts/acme/org/application.html.erb:25` & `.../com/application.html.erb:25` —
  `button_to ... acme_{org,com}_oidc_logout_path, method: :post` (**BAD — points at protocol
  endpoint**).
- `app/views/acme/shared/dashboards/show.html.erb:53` — `new_acme_{surface}_sign_out_path` (GOOD).
- `app/views/acme/shared/sign_outs/edit.html.erb` — confirmation; submits `DELETE` to `/sign/out`.
- `app/views/acme/shared/sign_outs/show.html.erb` — completion page (access-expiry display).
- `app/views/acme/shared/oidc/logouts/_confirmation_form.html.erb` — POST form, hidden
  `id_token_hint`/`post_logout_redirect_uri`/`state`/`client_id`/`ui_locales`/`ri`.
  `app/views/acme/shared/oidc/` is NEW untracked.

### Registry / discovery / services

- `app/services/oidc_client_registry.rb` + `oidc_client_stores_static_client_store.rb` — registered
  clients (`sign-rp`, `base-rails-rp`, `core-next-rp`, mobile, docs/news/help).
  **`post_logout_redirect_uris` are built per surface as `<host>/sign/out`**
  (`build_post_logout_redirect_uris`).
- `app/services/oidc_redirect_uri_validator.rb` — **exact-match** allowlist
  (`Array(...).include?(uri)`).
- `app/services/oidc_issuer.rb:37-39` — `end_session_endpoint => "<host>/oidc/logout"`;
  `oidc_discovery_document.rb:17` publishes it. `backchannel_logout_supported: true`.
- Token/session services: `oidc_end_session_request.rb` (validates `post_logout_redirect_uri`
  against registry), `oidc_logout_token_codec.rb` (logout_token encode/decode + JTI replay, UUID
  `sid`), `oidc_token_revocation_service.rb`, `oidc_rp_session_logout.rb` (revoke by `oidc_sid`),
  `oidc_backchannel_logout_notifier.rb`, `oidc_backchannel_logout_delivery_job.rb`,
  `oidc_logout_request.rb` (signed one-shot logout request), `logout_result.rb`.

### Answers to the 20 grill questions

1. **Acme sign-out routes**: app/com/org each `GET /sign/out/new`, `GET /sign/out/edit`,
   `DELETE /sign/out` (+ `GET/POST /oidc/logout`).
2. **Sign sign-out routes**: app `GET/POST /sign/out`; com/org `GET /sign/out` only.
3. **Core/Base**: implemented — `GET/POST /sign/out` per surface (Core also backchannel).
4. **Logout button → /oidc/logout?** YES — `acme/org` and `acme/com` nav (`button_to ... POST`).
5. **`_method=delete` for /oidc/logout?** NO. (The OIDC confirmation form is POST. The `DELETE` verb
   is on `/sign/out` only.)
6. **Acme self-redirects to /oidc/logout with id_token_hint?** YES — `acme/*/sign/outs#destroy`.
7. **`sot` generated/consumed**: issued in `SignOutNotice#issue_sign_out_notice_token!`, consumed in
   `consume_sign_out_notice_token`; threaded through `SignOidcLogout` → `/sign/out/edit?sot=`.
8. **Can `sot` leave browser completion?** YES — session-bound marker already exists.
9. **`/sign/out/complete` present?** NO — completion overloads `/sign/out/edit?sot=`.
10. **`/oidc/logout` Acme-only?** YES. Sign `/oidc/logout` is retired (test asserts RoutingError).
11. **Discovery `end_session_endpoint`?** YES, → `/oidc/logout`. Matches. Keep.
12. **`post_logout_redirect_uri` registered per surface?** YES, but as `<host>/sign/out` — must move
    to `<host>/sign/out/complete`.
13. **Allowlist exact-match?** YES (`OidcRedirectUriValidator`).
14. **Where to store logout state?** Rails session (`SIGN_OUT_NOTICE_SESSION_KEY` exists). See §5.
15. **Will state survive RP `reset_session` before complete?** Not as written — `reset_session`
    wipes it. See §5 for the fix.
16. **Already-signed-out behavior?** Currently inconsistent (JSON 422 on stale). See §4.
17. **Shared vs role-specific?** See §6.
18. **Backchannel idempotency?** `OidcRpSessionLogout` no-ops when no token matches `oidc_sid`;
    `logout_token` JTI replay-guarded. Already largely idempotent — assert it. See §6/§8.
19. **Conflicting tests?** See §8.
20. **Stale docs/ADRs?** See §2.

---

## 2. Doc / ADR contradictions

1. **`adr/logout-completion-boundary.md` (Accepted 2026-06-03)** mandates a _sign-hosted_
   `GET /signed-out`, with Acme redirecting cross-surface to the Sign host, and keeps
   `acme /sign/out` as the mutation route. **Decision: supersede it.** New ADR: completion is
   per-surface `/sign/out/complete` on the same surface; no cross-surface redirect; mutation is
   `POST /sign/out` (Acme) / `POST /oidc/logout` (protocol).
2. **Current code already violates that ADR** — it uses `/sign/out/edit?sot=`, not `/signed-out`.
   The supersession resolves code↔ADR drift in one move.
3. **`docs/security/logout-sequence.md`** is mostly compatible (Acme owns mutation; Sign is
   redirect-only) but predates `/sign/out/complete` and the `new|edit|create|complete` shape —
   update its "Stale Sign Routes" and add the unified contract.
4. **`docs/security/oidc-discovery-profile.md`** is correct (`end_session_endpoint => /oidc/logout`)
   — no change beyond reaffirming `/oidc/logout` is not a nav target.
5. **`adr/sign-residual-idp-surface-retirement.md`** stays authoritative (Sign is RP/credential
   gateway, no IdP logout) — the plan must keep `/oidc/logout` off Sign/Core/Base.

---

## 3. Proposed final route contract

Independent per surface (app/com/org), per engine. `{surface}` ∈ {app, com, org}.

### User-facing ceremony — ALL browser surfaces (Acme, Sign, Core, Base)

```
GET  /sign/out/new        -> outs#new       (prepare intent, redirect 303 -> edit)
GET  /sign/out/edit       -> outs#edit      (confirmation page; no mutation)
POST /sign/out            -> outs#create    (role-specific mutation; redirect 303)
GET  /sign/out/complete   -> outs#complete  (completion page; consumes session marker; no mutation)
```

Acme route shape: `resource :out, only: %i(new edit create), as: :sign_out` + an explicit
`get "out/complete"` member (resourceful `complete` is not a default). `DELETE /sign/out` removed.

### Protocol endpoint — Acme ONLY

```
GET  /oidc/logout         -> oidc/logouts#show     (validate; redirect to shared /sign/out/edit)
POST /oidc/logout         -> oidc/logouts#create   (perform end-session; redirect to validated
                                                    post_logout_redirect_uri or /sign/out/complete)
```

No `DELETE /oidc/logout`. Not present on Sign/Core/Base.

### Back-channel — RP surfaces (Sign, Core; Base if it holds sessions)

```
POST /oidc/backchannel_logout  (server-to-server; idempotent)
```

> NOTE: current path is `/oidc/backchannel/logout` (nested). Keep the existing path to avoid
> breaking registered `backchannel_logout_uris`; treat the task's `/oidc/backchannel_logout`
> spelling as logical, not a rename. (Renaming would require re-registering every client URI — out
> of scope.)

### Per-surface independence

- Each surface validates its own `post_logout_redirect_uri` against the registry entry for _that_
  surface's client. No shared session, client, or host assumptions.
- Acme completion redirect targets the _same_ Acme surface's `/sign/out/complete`.
- RP completion targets the _same_ RP surface's `/sign/out/complete` (registered URI).

### Palm (future, docs/plans only)

```
post_logout_redirect_uri = https://<palm-host>/sign/out/complete   (HTTPS Universal/App Link)
```

Native: purge secure-storage tokens + call Acme token revocation / family revoke; browser fallback
renders the friendly signed-out page. No native code now.

---

## 4. Decision table — no-session / already-signed-out

| Action                   | No active session / nothing to do                                                                                            | Stale/invalid completion                                                                                                                                        |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /sign/out/new`      | Redirect 303 → `/sign/out/edit` (edit decides). No mutation.                                                                 | n/a                                                                                                                                                             |
| `GET /sign/out/edit`     | Render friendly "You're already signed out" HTML with sign-in link. No protocol side effects, no redirect to `/oidc/logout`. | n/a                                                                                                                                                             |
| `POST /sign/out` (Acme)  | No session → render/redirect to friendly already-signed-out; do **not** revoke nothing-then-pretend. No `/oidc/logout`.      | n/a                                                                                                                                                             |
| `POST /sign/out` (RP)    | No local session AND no `id_token_hint` derivable → friendly already-signed-out; do **not** start protocol logout.           | n/a                                                                                                                                                             |
| `GET /sign/out/complete` | No session marker → friendly "signed out" HTML (fail closed). **Never** JSON 422.                                            | Refreshed/consumed marker → same friendly HTML; never re-assert a fresh logout.                                                                                 |
| `GET /oidc/logout`       | No session → if valid `post_logout_redirect_uri`, may redirect there; else friendly HTML. Never error to browser.            | n/a                                                                                                                                                             |
| `POST /oidc/logout`      | No session → treat as already-complete: redirect to validated `post_logout_redirect_uri` or `/sign/out/complete`.            | Replace JSON 422 (`render_oidc_end_session_failure`) with friendly HTML for browser; reserve JSON only for genuine protocol/`Accept: application/json` clients. |

Principle: **never trigger protocol side effects when sign-out is unnecessary**, and **never show a
browser user a JSON 422** for stale completion.

---

## 5. State-storage analysis (Rails session viability + pitfalls)

**Viable**, with one critical pitfall.

- **Acme local sign-out**: store the one-time completion marker in the Rails session
  (`SIGN_OUT_NOTICE_SESSION_KEY`) _after_ the logout primitive runs. `complete` consumes it once
  (delete-on-read) and fails closed. `sot` URL token is dropped for browser completion.
- **RP launcher (`POST /sign/out`)**: needs OIDC `state` (+ chosen `post_logout_redirect_uri`) to
  survive from launch until `/sign/out/complete`. **Pitfall:** `logout_current_session!` /
  `reset_session` wipes the Rails session — if `state` is written _before_ the reset it is lost.
  - **Fix (ordering contract):** within the same request: (1) capture intent, (2) run local cleanup
    primitive incl. `reset_session`, (3) **write OIDC logout state into the fresh post-reset
    session**, (4) redirect to Acme `/oidc/logout`. Rails `reset_session` installs a new empty
    session you can immediately write to, so state persists into the new session cookie.
  - Document this ordering in `docs/security/logout-sequence.md` and enforce it in a shared helper
    so no RP controller writes state pre-reset.
  - Alternative (rejected unless needed): a dedicated short-TTL signed cookie independent of the
    auth session. Keep session-based to match existing `SignOutNotice` machinery; note as fallback.
- **`/sign/out/complete` state validation (RP)**: compare returned `state` to the stored value, then
  delete it (one-time). Mismatch/missing → friendly HTML, no mutation.
- **Cache**: keep `sign_out_notice_cache_headers!` (`no-store`) on edit/create/complete and the
  protocol endpoint so completion is never cached/replayed from the browser.

---

## 6. Concern / service extraction plan

### A. Shared ceremony concern — `SignOutCeremony` (new, `app/controllers/concerns/`)

Common to Acme + RP `OutsController`s:

- `new` → 303 redirect to `edit` (preserving `ri`).
- `edit` → render shared confirmation OR friendly already-signed-out when no session.
- `complete` → consume session marker once, render friendly completion (fail closed).
- session-marker helpers (wrap `SignOutNotice` session key), `no-store` headers, common
  no-session/invalid handling. **No mutation here.** Keep shared views under
  `app/views/acme/shared/sign_outs/` (extend with `new`?/`complete`); RP surfaces render their own
  surface-scoped variants or the shared partial.

### B. Role-specific `create` strategies (keep authority vs launcher distinct — do not over-abstract)

- **Acme authority** (`Acme::*::Sign::OutsController#create`): call `logout_current_session!`
  (primitive), purge Acme cookies, enqueue back-channel notifications for related RPs, write
  session-bound completion marker, **303 → `/sign/out/complete`**. Must **not** mint `id_token_hint`
  for Acme itself; must **not** redirect to `/oidc/logout`. Remove `current_session_id_token_hint`
  and the `base-rails-rp` self-RP usage.
- **RP launcher** (`{Sign,Core,Base}::*::SignOutsController#create`): local cleanup primitive +
  `reset_session`, then write OIDC logout `state` into fresh session, **303 → Acme `/oidc/logout`**
  with `id_token_hint`, `state`, exact registered
  `post_logout_redirect_uri = <this surface>/sign/out/complete`. Extract the shared launcher body
  into `OidcRpLogoutLauncher` (concern or service) consuming existing `OidcIdTokenIssuer` +
  `OidcClientRegistry`.
- **Palm strategy** (future): documented only.

### C. Acme protocol handler — keep `SignOidcLogout`, adjust

- After protocol parse + **exact** `post_logout_redirect_uri` validation, `GET /oidc/logout` stores
  an Acme-side logout request in the session and **redirects to shared `/sign/out/edit`** for the
  common confirmation (decision #2), instead of rendering its own form.
- `POST /oidc/logout` performs end-session, then redirects to validated `post_logout_redirect_uri`
  (with `state` only after validation) or to `/sign/out/complete`.
- Replace `render_oidc_end_session_failure` JSON 422 with friendly HTML for browsers
  (content-negotiate).
- Stop threading `sot` into browser completion; use the session marker.

### D. Back-channel idempotency (existing services, assert + harden)

- `OidcRpSessionLogout` returns false / no-ops when no token matches `oidc_sid` → safe repeat.
- `OidcLogoutTokenCodec` JTI replay guard (10-min) → duplicate `logout_token` rejected safely.
- Receiver always returns 200 for valid-but-already-gone; never depends on browser return.

---

## 7. Implementation patch plan (by file group)

1. **Routes**
   - `config/routes/acme.rb` (×3 surfaces):
     `resource :out, only: %i(new edit create), as: :sign_out`
     - `get "out/complete", to: "sign/outs#complete", as: :complete_sign_out`. Remove `destroy`.
       Keep `resource :logout, only: %i(show create)`.
   - `config/routes/{sign,core,base}.rb`: ensure each browser surface exposes
     `new/edit/create/complete` (today they are `show`/`create`). Add `new`, `edit`, `complete`; map
     `create` to launcher. Com/Org Sign currently `show`-only — extend to full ceremony
     (independently per surface).
2. **Acme controllers**
   - `acme/{app,com,org}/sign/outs_controller.rb`: include new `SignOutCeremony`; implement
     authority `create`; add `complete`; delete `destroy` + `current_session_id_token_hint` +
     `base-rails-rp` self-RP path.
   - `acme/{app,com,org}/oidc/logouts_controller.rb` + `concerns/sign_oidc_logout.rb`: GET →
     redirect to shared `/sign/out/edit`; friendly-HTML failure; session-marker completion; exact
     redirect-URI validation already present (reaffirm).
3. **RP controllers** — `{sign,core,base}/**/sign_outs_controller.rb` (+ `sign/**/sign/outs`):
   include `SignOutCeremony` + new `OidcRpLogoutLauncher`; enforce post-reset state ordering (§5);
   `post_logout_redirect_uri = <surface>/sign/out/complete`.
4. **Concerns (new/edit)** — add `app/controllers/concerns/sign_out_ceremony.rb`,
   `oidc_rp_logout_launcher.rb`; edit `sign_oidc_logout.rb`, `sign_out_notice.rb` (favor session
   marker), keep `authentication_logoutable.rb`.
5. **Views** — `app/views/layouts/acme/{org,com}/application.html.erb`: change logout
   `button_to /oidc/logout` → `link_to new_acme_{surface}_sign_out_path` (match app). Add/adjust
   shared `sign_outs/{new?,edit,complete}.html.erb`; ensure already-signed-out friendly variant. RP
   surface views for new/edit/complete.
6. **Registry** — `oidc_client_stores_static_client_store.rb`: `build_post_logout_redirect_uris`
   emits `<host>/sign/out/complete` (per surface, per client: `sign-rp`, `core-next-rp`, future
   palm). Drop/repurpose `base-rails-rp` self-RP usage for Acme local logout (Acme no longer RPs
   itself).
7. **Discovery** — no change to `oidc_issuer.rb` / `oidc_discovery_document.rb` (still
   `/oidc/logout`); reaffirm in docs that it is not a nav target.
8. **Docs/ADR** — new ADR superseding `logout-completion-boundary.md`; update
   `docs/security/logout-sequence.md` (unified contract + post-reset state ordering + Palm), add
   Palm interface note to plans. Add `notes/implementation/` handoff note.

---

## 8. Test plan (exact files)

### Route contract — `test/integration/routes/`

- `acme_route_contract_test.rb`: replace `new/edit/destroy` assertions (lines ~112-123, ~458-469,
  ~658-669) with `GET /sign/out/new`, `GET /sign/out/edit`, `POST /sign/out`,
  `GET /sign/out/complete`; assert `DELETE /sign/out` NOT recognized; `GET/POST /oidc/logout`
  recognized; `DELETE /oidc/logout` NOT recognized. All three surfaces independently.
- `sign_route_contract_test.rb` (+ core/base equivalents): assert `new/edit/create/complete` per
  surface; `/oidc/logout` NOT recognized on Sign/Core/Base; `POST /oidc/backchannel/logout`
  recognized on RP surfaces.

### Layout / dashboard

- New/updated test asserting `acme/{org,com}` nav logout points to `new_*_sign_out_path`, not
  `/oidc/logout`; no user-facing `/oidc/logout` form in dashboard/header.

### Acme — `test/controllers/acme/{app,com,org}/sign_outs_controller_test.rb`

- `GET new` 303 → edit, no mutation; `GET edit` no mutation; `POST create` performs direct Acme
  logout (session revoked, cookies cleared); `POST create` does **not** redirect to `/oidc/logout`
  and emits no `id_token_hint`; `POST create` 303 → `/sign/out/complete`; `complete` renders
  friendly HTML from session marker; no `sot` JSON stale response; already-signed-out → friendly
  HTML.

### Acme OIDC — `test/controllers/acme/{app,com,org}/oidc/logouts_controller_test.rb`

- Update redirect target: `GET /oidc/logout` (with session) → `/sign/out/edit` (replace prior
  `/sign/out/edit?sot=` assertions at app:94/96, com:88, org:93). `POST /oidc/logout` → validated
  `post_logout_redirect_uri` or `/sign/out/complete`. Exact redirect-URI match; invalid URI never
  used; `state` returned only after validation; stale completion → friendly HTML (not JSON 422); no
  DELETE.

### RP — `test/controllers/{sign,core,base}/**/sign_outs_controller_test.rb`

- `POST create` writes state (post-reset), redirects to Acme `/oidc/logout` with `id_token_hint`,
  `state`, exact registered `post_logout_redirect_uri = <surface>/sign/out/complete`; local cleanup
  before redirect; `complete` validates state; invalid/expired state → friendly HTML;
  already-signed- out → no protocol start.
- Add a focused test proving `state` survives `reset_session` (the §5 pitfall).

### OIDC services — existing, extend

- `test/services/oidc/backchannel_logout_notifier_test.rb`, `oidc_redirect_uri_validator` coverage:
  exact-match enforced; `oidc_end_session_request` rejects unregistered URI.

### Back-channel — `test/.../oidc/backchannel/logouts_controller_test.rb` + job test

- Valid `logout_token` clears session by `sid`/`sub`; repeated/already-gone is idempotent (200, no
  error); invalid `logout_token` rejected.

### Registry — `test/services/oidc_client_stores_static_client_store_test.rb` (or equivalent)

- `post_logout_redirect_uris` end in `/sign/out/complete` per surface/client.

### Pre-existing reds to resolve (from `plans/rails-log-peppy-harp.md:201-209`)

- `acme/app/sign_outs_controller_test.rb` GET rendered empty completion vs expected confirmation,
  and nil `current_session_public_id` — both subsumed by the new `edit`/`create` split + session
  wiring.

### Palm (docs/plans assertions only)

- Plan/docs state Palm completion URI = HTTPS `/sign/out/complete` Universal/App Link and document
  native token revocation/family revoke as required future behavior.

---

## 9. Risks & open questions

1. **`base-rails-rp` removal blast radius** — confirm nothing else relies on Acme acting as its own
   RP before deleting `current_session_id_token_hint`. (grep `base-rails-rp`.)
2. **Backchannel path spelling** — task says `/oidc/backchannel_logout`; code/registry use
   `/oidc/backchannel/logout`. Plan keeps existing nested path to avoid re-registering client URIs.
   Confirm acceptable, or schedule a separate coordinated rename + re-registration.
3. **Post-reset session write** — must verify the host/cookie domain lets a freshly reset session
   persist across the redirect to Acme on a _different_ host (RP host vs Acme host). The `state`
   lives in the RP-host session and is read back at the RP-host `/sign/out/complete`, so cross-host
   is fine, but test it explicitly.
4. **Com/Org Sign currently `show`-only / `:bare`** — extending to full ceremony must respect their
   bare authentication mode; verify ceremony works without app-wide auth callbacks.
5. **Discovery cache** — `end_session_endpoint` unchanged, safe; but ensure no doc/test still
   expects completion at `/sign/out/edit?sot=`.
6. **Migration ordering** — routes + controllers + tests must land together (hard cut) to avoid a
   half-renamed contract; run full route contract + sign-out controller suites before push.

---

## 10. Verification

After implementation (NOT now — stop here unless told to implement):

```
bin/rails test test/integration/routes/acme_route_contract_test.rb \
  test/integration/routes/sign_route_contract_test.rb
bin/rails test test/controllers/acme test/controllers/sign \
  test/controllers/core test/controllers/base
bin/rails test test/controllers/concerns/sign_out_notice_test.rb \
  test/services/oidc
```

Manual: drive each surface's `/sign/out/new → edit → create → complete`; confirm Acme never hits
`/oidc/logout`, RP launchers do; confirm stale `/sign/out/complete` shows friendly HTML (no JSON
422); confirm `acme/org` + `acme/com` nav logout lands on the ceremony; confirm
`/.well-known/openid-configuration` still advertises `end_session_endpoint = /oidc/logout`.

---

**STOP — planning only. Do not implement until explicitly told to proceed.**
