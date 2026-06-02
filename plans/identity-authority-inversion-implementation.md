# Identity Authority Inversion Implementation Plan

## Status

Active controlling implementation plan.

This plan implements the current ADR direction established by:

- `adr/identity-authority-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/sign-credential-gateway-surface.md`

The first implementation slice is tracked in
`plans/active/identity-authority-inversion-first-slice.md`.

## Context

The identity architecture has moved away from a `sign/id` IdP and `acme/www` RP model. `acme/www` is
now the Session, Token, Account, Preference, Authorization, and downstream-token Authority.
`sign/id` is now a Credential Gateway and Credential Ceremony Zone only.

This is an authority inversion, not a refactor. Historical plans that place settings, preferences,
dashboards, session management, token issuance, account lifecycle, or step-up freshness on `sign/id`
are deprecated for those authority assignments.

## Non-Goals

- Do not move physical database tables in this implementation phase.
- Do not rewrite the whole sign-in, sign-up, logout, preference, or step-up implementation in one
  slice.
- Do not delete historical plans.
- Do not treat existing stable `docs/` as proof that implementation has already completed the
  inversion. Where docs state the accepted boundary before code has caught up, the implementation
  gap must be called out in the active slice.
- Do not change application code as part of plan-maintenance work.

## Current Implementation Gaps

The following known implementation gaps must be resolved or fenced by active slices:

- sign `/sign/out` still performs direct session logout in existing controllers.
- sign edge token refresh still performs refresh token mutation.
- sign OAuth/OIDC token routes still expose token authority behavior.
- sign dashboard, welcome, settings, preference, session-management, and withdrawal routes still
  exist as sign-side authority-looking surfaces.
- sign step-up ceremony code still writes session-freshness fields directly.
- sign social callback and sign-up flows still perform some account linking or account finalization.

These gaps are compatibility implementation only. They do not override the accepted authority
boundary.

## Authority Boundary

`acme/www` owns:

- user sessions;
- refresh token families;
- access-token issuance for `acme/www`;
- downstream token issuance for `core`, `line`, and future downstream services;
- account lifecycle;
- preference writes and preference management;
- authorization decisions;
- dashboards and session-management UI;
- logout, session rotation, session revocation, device/session listing, compromise state, and
  step-up freshness.

`sign/id` owns only:

- credential inventory needed to execute credential ceremonies;
- short-lived credential ceremony state;
- WebAuthn/passkey, OTP/TOTP, social provider callback validation, credential enrollment, credential
  assertion, and step-up ceremony execution;
- ceremony audit records.

`sign/id may execute credential ceremonies, but acme/www consumes results and commits session/account/preference/token state.`

`OIDC, refresh, step-up freshness, and downstream token issuance are acme authority.`

Old plans that assign settings, preference, dashboard, session-management, token issuance, account
lifecycle, or step-up freshness to sign/id are deprecated.

## Physical Storage Boundary

Logical authority moves now; physical DB movement is out of scope.

Existing sign-side tables/models do not imply sign-side authority.

During this implementation phase, existing tables, models, namespaces, and route names may remain in
their current physical locations while the logical owner changes to `acme/www`. Any code path that
continues to use a physically sign-side table must treat it as compatibility storage or ceremony
storage unless a current ADR explicitly assigns credential inventory ownership to `sign/id`.

Do not use physical database location as an argument for restoring sign-side sessions, refresh
tokens, preference writes, dashboards, account lifecycle, downstream token issuance, authorization
decisions, or step-up freshness.

## Deprecation Target List

The following plans are deprecated or partially deprecated where they assign identity authority to
`sign/id`:

- `plans/active/acme-rp-boundary-rename.md`
- `plans/active/sign-authentication-surface-inventory-and-terminology-plan.md`
- `plans/active/sign-in-state-machine-implementation-plan.md`
- `plans/active/sign-in-state-machine-authentication-authorization-plan.md`
- `plans/active/sign-up-state-machine-implementation-plan.md`
- `plans/active/logout-state-machine-implementation-plan.md`
- `plans/active/step-up-authentication-rebuild.md`
- `plans/active/token-rotation-concurrency-hardening.md`
- `plans/active/withdrawal-state-machine-implementation-plan.md`
- `plans/active/preference-actor-hydration-ssot.md`
- `plans/active/preference-jwt-runtime-cache-migration.md`
- `plans/active/identity-control-plane-configuration-hardening.md`

Backlog and archive plans remain historical unless promoted by a current ADR or this plan. If a
future slice promotes a backlog/archive plan that assigns identity authority to `sign/id`, add a
banner before using it.

## Implementation Slices

1. Plan deprecation banners
   - Mark active plans that can mislead implementers back into sign-side authority.
   - Keep historical content intact.

2. Route/controller inventory
   - Inventory routes and controllers that currently expose settings, preference, dashboard,
     session-management, token, account lifecycle, and step-up freshness behavior under `sign/id`.
   - Classify each route as credential ceremony, compatibility transport, acme-owned authority
     surface, or deprecated.

3. `sign/id` ceremony-only enforcement
   - Keep WebAuthn/passkey, OTP/TOTP, social callback validation, credential enrollment, credential
     assertion, and step-up ceremony execution on `sign/id`.
   - Require acme-issued ceremony grants and signed ceremony results for delegated ceremonies.
   - Prevent `sign/id` from committing session, account, preference, token, authorization, or
     freshness state.

4. `acme/www` authority wiring
   - Move logical session, account, preference, authorization, and token decisions to `acme/www`
     services/controllers.
   - Treat sign-side storage as compatibility storage where physical movement is deferred.

5. Preference/settings/dashboard relocation by logical owner
   - Reclassify sign-side settings, preference, dashboard, activities, and session-management UI as
     acme-owned surfaces or deprecated routes.
   - Keep credential enrollment screens only where they are credential ceremonies.

6. Session/token/refresh/step-up authority cleanup
   - Ensure session issuance, refresh token family rotation, logout, revoke, device/session listing,
     compromise state, and step-up freshness are committed by `acme/www`.
   - Ensure `sign/id` ceremony success is evidence only until `acme/www` consumes the result.

7. Downstream token trust cleanup
   - Ensure `core`, `line`, and future downstream services trust only acme-issued downstream tokens.
   - Remove or fence assumptions that sign-issued access/session/downstream tokens are trusted by
     downstream services.

8. QA/security docs refresh
   - After implementation slices establish behavior, update stable docs and QA/security checklists.
   - Include negative tests proving `sign/id` cannot own sessions, refresh tokens, preference
     writes, dashboards, account lifecycle, downstream token issuance, authorization decisions, or
     step-up freshness.

## QA And Security Follow-Up Requirements

- Add route/controller inventory evidence before moving behavior.
- Add negative tests for prohibited `sign/id` responsibilities.
- Add ceremony grant/result replay, audience, purpose, expiry, one-shot, and session/transaction
  binding tests.
- Add tests that `core` and `line` reject sign-issued session/access/downstream tokens.
- Add tests that `sign/id` ceremony audit does not update step-up freshness.
- Add tests that existing sign-side tables/models do not cause sign-side authority decisions.
- Add security review for WebAuthn RP ID/origin, social callback boundary, cookie isolation, and
  redirect/callback result transport.

## Docs Follow-Up Requirements

Do not update stable `docs/` during this plan-maintenance slice.

After implementation slices land, update docs for:

- identity authority boundary;
- acme session and token authority;
- sign credential gateway surface;
- delegated credential ceremony grant/result;
- step-up ceremony delegation;
- WebAuthn RP ID and origin boundary;
- social login callback boundary;
- preference/settings/dashboard authority;
- cookie domain and session isolation;
- downstream token authority;
- redirect transaction and ceremony result transport.
