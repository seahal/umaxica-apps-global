# Sign-In Routing & Ceremony — Audit and Scoped Migration Plan

## Context

The task brief asks for a "complete hard migration" of sign-in routing, premised on `/auth/*` being
"semantically chaotic and freaky" and "used for multiple unrelated meanings."

A full audit (routes, controllers, concerns, services, ADRs, docs, tests, OmniAuth config, client
registry, frontend) shows **that premise is substantially out of date**. A prior migration already
established the exact canonical vocabulary the brief targets. The headline deliverable is already
met:

> **No runtime `/auth/*` route exists anywhere.** `auth` survives only as an _internal controller
> namespace_ (e.g. `Acme::App::Auth::CallbacksController`). The brief §2.5 explicitly forbids
> blindly renaming internal `Auth::` classes.

Per `AGENTS.md` decision priority (current code/tests #2 and accepted ADRs #3 outrank a brief
premised on stale information) and `no-compatibility-layer.mdc`, the responsible action is to **call
out the conflict before bulldozing a mature, ADR-locked system**, then execute a scoped cleanup of
the genuine remaining deltas — not a destructive rewrite that re-litigates accepted architecture and
risks broad regression.

This file records the verified state, the three real deltas, and the recommended scope.

---

## Verified current contract (already implemented)

Hosts isolate surfaces (`constraints host:`); products use `scope module:`. app/com/org are
independent everywhere.

| Concern             | Route(s)                                                                                             | Owner                                     | Status                  |
| ------------------- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------- | ----------------------- |
| Human sign-in entry | `GET /sign/in` (+ rich `/sign/in/{email,passkey,secret_credential,session,check,guard,challenge/*}`) | Sign (app/com/org)                        | ✓ matches §2.1/§6       |
| OAuth AS protocol   | `GET /oauth/authorize`, `POST /oauth/token`, `GET /oauth/userinfo`, `POST /oauth/revoke`             | Acme only (app/com/org)                   | ✓ matches §2.2/§6.6     |
| OIDC protocol       | `GET/POST /oidc/logout`, `POST /oidc/backchannel/logout`                                             | Acme (logout) / RP surfaces (backchannel) | ✓ matches §2.4          |
| Discovery / JWKS    | `/.well-known/openid-configuration`, `/.well-known/jwks.json`                                        | Acme                                      | ✓                       |
| Social ceremony     | `/social/*` (OmniAuth `path_prefix=/social`), app-only, blocked on com/org                           | Sign (app) + Acme social result consumer  | ✓ matches §2.3/§9       |
| Sign-out            | `GET /sign/out/{new,edit,complete}`, `POST /sign/out`                                                | all browser surfaces                      | ✓ ADR-locked 2026-06-21 |
| Palm                | app-only (`/oidc/authorization`, `/oidc/callback`, `/api/v0/*`); no com/org                          | Palm                                      | ✓ matches §1.4          |

**Acme ↔ Sign handoff is already the brief's target design (§6.6/§6.7/§7):** Acme `/oauth/authorize`
(unauthenticated) issues a server-side `ClientOidcAuthorizationTransaction` keyed by an opaque
`login_challenge` (DB-authoritative, row-locked, 10-min TTL, one-time `consume!`), redirects to Sign
`/sign/in?login_challenge=…`; Sign runs the ceremony, calls `register_result!` (records
actor/session/amr/acr), and redirects to `/oauth/authorize?login_challenge=…`; Acme
`resume_authorization!` validates expired/consumed/authenticated, calls `log_in` (Acme-only central
session), `consume!`, then issues the code. Sign never mints tokens or sessions. The opaque
server-side transaction is one of the brief's explicitly blessed mechanisms (§7.2).

**Shared RP callback machinery is clean** (`app/controllers/concerns/oidc_callback.rb` +
`oidc_sso_initiator.rb`): state via `secure_compare`, one-time `session.delete` of
PKCE-verifier/state/nonce, issuer+audience+nonce verification (`OidcIdTokenVerifier`), session
fixation reset with explicit OIDC-state preservation, `pt` return-target consumed once.

**Tests already enforce the contract:** `test/integration/routes/acme_route_contract_test.rb` and
`sign_route_contract_test.rb` assert canonical paths and that removed verbs (e.g.
`DELETE /sign/out`, `DELETE /oidc/logout`) raise `RoutingError`; social routes absent on com/org.

---

## Genuine remaining deltas vs. the brief's literal target

**D1 — RP launcher/callback live under `/oidc/*`, not `/oauth/callback`.** RP-side endpoints are
`GET /oidc/authorization` (launcher) and `GET /oidc/callback` (callback) on Acme, Sign, Core, Base,
Palm. The brief §2.4 _prefers_ RP callbacks at `/oauth/callback` and reserves `/oidc/*` for OP
protocol. Counter-evidence: these _are_ OIDC RP endpoints, consistently named, host-isolated, with
shared clean machinery — not the "freaky overloaded `/auth`" the brief describes. Renaming has a
**large blast radius and an external blocker**: native deep-links are registered as
`umaxica://oidc/callback` / `com.umaxica.app:/oidc/callback`
(`oidc_client_stores_static_client_store.rb`) and provider/console redirect URIs are registered
against current paths. Per §2.5/§3, externally-registered callbacks are a valid reason a path stays.

**D2 — Internal controller-namespace inconsistency.** RP controllers are `*/Auth::*` on
Acme/Core/Base/Palm but `*/Oidc::*` on Sign. Purely internal; the brief §2.5 says do not blindly
rename internal `Auth::`. Optional consistency pass only.

**D3 — Acme `app` surface acts as an RP to its own OP (the only real §1.1 smell).**
`Acme::App::Auth::AuthorizationsController#show` calls `initiate_oidc_session!` → redirects to
Acme's own `/oauth/authorize` as client `base-rails-rp` (comment: _"Historical name for Acme's own
browser RP callback"_), then `/oidc/callback` runs `OidcCallback#log_in` — a second `log_in` on the
same host after the OP's `resume_authorization!` already called `log_in`. The brief §1.1 forbids
"Acme acting as an RP to itself merely to complete local sign-in." This needs a decision:
intentional (Acme product browser surface deliberately modeled as an RP, distinct from OP authority
session) vs. a legacy circular path to collapse.

---

## Confirmed scope (approved: targeted cleanup; D3 = investigate first)

User decisions: **(1) targeted cleanup, not a full rewrite; (2) D3 — investigate before deciding, no
behavior change this pass.** Execution:

1. **Confirm & document the already-met goal.** Add/strengthen negative route tests asserting no
   `/auth/*` runtime path resolves on every surface/product (extend
   `test/integration/routes/{acme,sign}_route_contract_test.rb`; add Core/Base/Palm equivalents
   where missing). Amend `adr/acme-rp-boundary-naming.md` to record the accepted HTTP vocabulary and
   that `Auth::` is an internal controller namespace, not an HTTP path — so a future agent does not
   re-attempt the "/auth eradication" on stale premise. **No runtime route changes.**
2. **D3 — investigation only (no code change).** Produce a `notes/implementation/` findings note
   tracing the `base-rails-rp` Acme-app self-RP: what session(s) the double `log_in` establishes (OP
   `resume_authorization!` vs RP `OidcCallback`), token kinds, why a same-host RP round-trip exists,
   its relationship to Core/Base and the cookie-domain boundary
   (`adr/cookie-domain-scope-by-surface.md`), and whether it is removable. Record the §1.1 tension,
   evidence checked, and a recommended follow-up (collapse vs keep-and-document) for a separately
   scoped decision. Do **not** modify the controllers, registry, or `OidcCallback` in this pass.
3. **D1 — keep `/oidc/*` RP vocabulary.** Record it in the same ADR amendment as an accepted
   deviation from the brief's `/oauth/callback` preference, citing the native-deep-link
   (`umaxica://oidc/callback`) + provider-registration external blocker (brief §2.5). Do **not**
   mass-rename.
4. **D2 — out of scope this pass.** The internal `Auth::`→`Oidc::` namespace rename is optional,
   purely cosmetic, and gated behind the D3 investigation (which touches the same Acme `Auth::`
   controllers); defer to avoid a double move. Note it as a follow-up in the ADR/handoff.

This honors the brief's _intent_ (clear ownership, no `/auth` chaos, one-time audience-bound
handoff, Palm app-only, sign-out non-regression) without destabilizing accepted, test-covered work.

---

## Files this pass

**Edit (the only changes):**

- `test/integration/routes/{acme,sign}_route_contract_test.rb` — add negative `/auth/*` assertions;
  add Core/Base/Palm route-contract coverage where missing
- `adr/acme-rp-boundary-naming.md` (amend) — accepted HTTP vocabulary; `Auth::` is an internal
  namespace not an HTTP path; D1 `/oidc/*`-RP deviation + external-blocker rationale; D2 follow-up
- `notes/implementation/<date>-acme-app-self-rp-base-rails-rp.md` (new) — D3 investigation findings

**Read-only for the D3 investigation:**

- `app/controllers/acme/app/auth/{authorizations,callbacks}_controller.rb` (+ com/org)
- `app/controllers/concerns/{oidc_callback,oidc_sso_initiator}.rb`
- `app/controllers/acme/app/oauth/authorizations_controller.rb` (OP authorize/resume)
- `app/services/oidc_client_stores_static_client_store.rb` (`base-rails-rp` + redirect URIs)
- `config/routes/{acme,core,base,palm}.rb`; `adr/cookie-domain-scope-by-surface.md`

## Verification

```bash
bin/rails routes -g 'sign/in'; bin/rails routes -g 'oauth'; bin/rails routes -g 'oidc'
bin/rails routes -g 'social'; bin/rails routes -g 'sign/out'
bin/rails routes | grep -E ' /auth(/| )'   # expect: no rows
bin/rails test test/integration/routes test/controllers/acme test/controllers/sign \
  test/integration/oidc_rp_browser_flow_test.rb test/integration/base_palm_auth_entrypoints_test.rb
bin/rails test test/controllers/acme/app/sign_outs_controller_test.rb \
  test/controllers/sign/app/sign_outs_controller_test.rb   # sign-out non-regression
bin/rails zeitwerk:check && git diff --check
```
