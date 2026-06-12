# Identity Authority Boundary Implementation Plan

## Status

Superseded by `adr/acme-sign-core-base-port-boundary.md` where this plan uses the older Rails-only
`acme/www` / `sign/id` authority model. The target boundary is Acme as the only IdP / Authorization
Server, Sign as a special RP, Core as the Next.js web RP/BFF, Base as the Rails
foundation/control-plane subdomain, and Port as the native bearer-token API Resource Server.

Superseded by `adr/sign-residual-idp-surface-retirement.md` where this plan assigns Identity,
Refresh, Logout, Step-up freshness, Preference, or app social link/unlink authority to `sign/id`.

Do not use this plan to reintroduce Sign IdP, session, refresh, token, preference, account, or
settings authority. The current implementation direction is Acme-only IdP with Sign retained as the
`id.*` credential-gateway and ceremony host boundary.

The first implementation slice is tracked in
`plans/active/identity-authority-inversion-first-slice.md`.

## Context

The current authority split is:

- `sign/id` owns Identity, Credential, Refresh, Logout, Step-up, browser/request Preference, and app
  social link/unlink authority.
- `acme/www` owns Account, Organization, Avatar, Selector, Dashboard, RP Authorization, and SNS-body
  authority.

This is an authority boundary correction, not a physical database move. Existing tables, route
helpers, and namespaces may remain where they are while code is routed through the correct logical
authority.

## Non-Goals

- Do not move physical database tables in this implementation phase.
- Do not rewrite the whole sign-in, sign-up, logout, preference, refresh, social, or step-up
  implementation in one slice.
- Do not delete historical plans.
- Do not treat existing stable `docs/` as proof that implementation already matches this boundary.
  Where docs state an older boundary, call out the conflict before implementing.
- Do not change application code as part of plan-maintenance work.

## Current Implementation Gaps

The following known implementation gaps must be resolved or fenced by active slices:

- Sign refresh/logout/session-revocation code exists, but some paths still call token primitives
  directly from controllers instead of going through a Sign authority facade with durable,
  idempotent state transitions.
- Sign step-up code exists, but Acme business mutations must consume a verifiable Sign step-up
  result instead of letting the business mutation complete inside a Sign-only flow.
- Sign app social callback/sign-up code exists, but the callback must not create durable
  Client/provider identity/ClientAccount records before the pending evidence, guard/check, and
  confirmation flow reaches the approved finalization point.
- Acme preference routes/controllers/dispatch still expose old acme preference-authority behavior.
- Acme app social link/unlink compatibility must not perform durable identity mutation; it must
  delegate to Sign app social authority.
- External RP-facing OIDC provider routes must be separately classified as retained, delegated, or
  retired. If external RP service is being ended, the target is route/controller/link removal, not
  moving those endpoints to Acme.
- Sign account/organization/avatar/dashboard/SNS-body routes or controllers must not mutate Acme
  business authority state except through explicit delegation.

These gaps are compatibility implementation only. They do not override the accepted authority
boundary.

## Authority Boundary

`sign/id` owns:

- identity entry and authentication flows;
- credential inventory and credential ceremonies;
- app Google/Apple social login callback validation and app social link/unlink authority;
- refresh token rotation, refresh token family revocation, session-token revocation, and logout;
- step-up verification and freshness evidence;
- browser/request preference state used before and during identity entry: language, region,
  timezone, color theme, cookie consent, and Preference JWT/cookie issuance, update, and revocation;
- durable identity/security audit records for the above authority areas.

`acme/www` owns:

- account lifecycle and account finalization after approved identity evidence;
- organization, avatar, billing, dashboard, activity, and SNS-body behavior;
- selector and account-choice outcomes;
- RP authorization decisions and business-surface authorization;
- consumption of Sign-issued identity, refresh/logout, step-up, preference, and social results where
  Acme business behavior depends on them.

`sign/id` must not own Account, Organization, Avatar, Dashboard, RP Authorization, or SNS-body
business mutations.

`acme/www` must not own Identity, Credential, Refresh, Logout, Step-up, browser/request Preference,
or app social link/unlink durable mutations.

## Vocabulary Boundary

Use `Preference` only for browser/request preference state:

- language;
- region;
- timezone;
- color theme;
- cookie consent;
- Preference JWT/cookie lifecycle;
- pre-auth display settings.

Do not use `Preference` for Account, Organization, Avatar, Billing, Dashboard, Activity, or SNS-body
settings. Use names such as `AccountSetting`, `OrganizationSetting`, `AvatarSetting`, or
`DashboardSetting` when those domains need configuration surfaces.

## Physical Storage Boundary

Logical authority moves now; physical DB movement is out of scope.

Existing sign-side storage may support Sign authority for identity, credential, refresh, logout,
step-up, preference, and app social link/unlink behavior.

Existing acme-side storage may support Acme authority for account, organization, avatar, selector,
dashboard, RP authorization, and SNS-body behavior.

Do not use physical database location as an argument for restoring the wrong logical authority.

## Deprecation Target List

The following plans are deprecated or partially deprecated where they assign Sign authority to Acme
or Acme authority to Sign:

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
future slice promotes a backlog/archive plan that uses the old `sign/id` ceremony-only or Acme
preference/refresh/logout/step-up authority model, add a banner before using it.

## Implementation Slices

1. Plan deprecation banners
   - Mark active plans that can mislead implementers back into the old Acme aggregation model.
   - Keep historical content intact.

2. Route/controller inventory
   - Inventory routes and controllers that currently expose Sign authority behavior under Acme or
     Acme authority behavior under Sign.
   - Classify each route as Sign authority, Acme authority, compatibility transport, delegated
     endpoint, external-RP-retirement target, or deprecated.

3. Sign authority facade cleanup
   - Route refresh, logout, session-token revocation, step-up, Preference JWT/cookie, and app social
     link/unlink mutations through explicit Sign authority services.
   - Require durable state transitions, idempotency, replay protection, family revocation where
     applicable, and clear audit events.
   - Avoid controller-level direct token or identity mutation primitives.

4. Acme compatibility cleanup
   - Reclassify Acme preference routes/controllers as compatibility redirects or JumpRT delegation
     to Sign.
   - Reclassify Acme app social link/unlink routes/controllers as compatibility delegation to Sign.
   - Ensure Acme account, organization, avatar, selector, dashboard, RP authorization, and SNS-body
     behavior does not leak into Sign controllers.

5. Social sign-up boundary cleanup
   - Keep app social callback validation on Sign.
   - Ensure unregistered callback creates pending evidence only.
   - Create durable Client/provider identity/ClientAccount records only after the approved
     confirmation/checkpoint finalization point.
   - Existing IdP conflicts should not create a second identity; they should route to the
     appropriate login or account-selection flow.

6. External RP/OIDC cleanup
   - Classify external RP-facing OIDC provider behavior separately from internal Sign refresh/logout
     authority.
   - If external RP service is ending, remove routes/controllers/links and tests for the retired
     provider surface instead of moving it to Acme.

7. QA/security docs refresh
   - After implementation slices establish behavior, update stable docs and QA/security checklists.
   - Include negative tests proving Acme cannot perform Sign authority mutations and Sign cannot
     perform Acme business authority mutations.

## QA And Security Follow-Up Requirements

- Add route/controller inventory evidence before moving behavior.
- Add negative tests that Acme preference compatibility routes do not perform durable Preference
  writes or Preference JWT/cookie issuance, update, or revocation.
- Add negative tests that Acme app social compatibility routes do not create, link, or unlink
  durable identities directly.
- Add refresh/logout/session-revoke tests for Sign authority facade usage, idempotency, replay
  protection, and family revocation where applicable.
- Add tests that Acme business mutations consume verifiable Sign step-up results instead of relying
  on Sign-side business mutation completion.
- Add social callback tests proving pending evidence is created before confirmation and durable
  account/provider records are created only at the approved finalization point.
- Add tests for existing IdP collision handling without duplicate identity creation.

## Docs Follow-Up Requirements

Do not update stable `docs/` during this plan-maintenance slice.

After implementation slices land, update docs for:

- identity authority boundary;
- Sign refresh/logout/session-revocation authority;
- Sign step-up authority and Acme result consumption;
- Sign Preference authority and Account/Organization/Avatar/Dashboard setting vocabulary;
- app social link/unlink authority;
- Acme account, organization, avatar, selector, dashboard, RP authorization, and SNS-body authority;
- external RP/OIDC retirement or retained-provider policy;
- cookie domain and session isolation;
- redirect transaction and JumpRT result transport.
