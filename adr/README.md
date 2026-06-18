# Architecture Decision Records

This directory stores accepted architecture and design decisions.

- Write ADRs in English. Do not add Japanese or other non-English prose unless the ADR explicitly
  discusses localization, translation data, or a quoted source whose original language matters.
- Keep decision records focused on what was decided and why.
- Include tradeoffs when they matter to future readers.
- Update `docs/` separately when implementation changes become current behavior.
- Keep non-authoritative decision notes and implementation handoff notes in `notes/`, not under
  `adr/`.

Current identity authority decision:

- `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md` — current source of
  truth for Core browser credential transport on `jp.umaxica.app`: Rails Core may consume a
  short-lived `core-browser` access JWT only from an HttpOnly host-only cookie, refresh remains
  opaque, reverse audience/transport use is rejected, and no `Cookie` header may reach Next.js or
  Side origins.
- `adr/core-browser-credential-transport.md` — superseded predecessor retained for traceability.
- `adr/acme-sign-core-base-port-boundary.md` — current source of truth for the target component
  model: Acme is the only IdP / Authorization Server, Sign is a special RP, Core is the Next.js web
  RP/BFF, Base is the Rails foundation/control-plane subdomain, and Palm is the native bearer-token
  API Resource Server formerly tracked as Port. Its `__Host-core_sid`-only Core browser credential
  model is superseded by `adr/core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md`.
- `adr/identity-authority-boundary.md` — current source of truth for Session, Token, Account,
  Preference, Authorization, Credential Gateway, ceremony-result, and downstream-token authority
  within the older Rails-only `acme/www` / `sign/id` model; superseded where it conflicts with the
  Acme / Sign / Core / Base / Palm component model.
- `adr/acme-session-and-token-authority.md` — refines the older identity authority boundary for
  `acme/www` owned user sessions, refresh-token families, step-up freshness, logout, session
  listing, compromise state, and downstream token issuance; superseded where it conflicts with the
  Acme / Sign / Core / Base / Palm component model.
- `adr/sign-credential-gateway-surface.md` — refines the identity authority boundary for permitted
  `sign/id` credential inventory, ceremony state, ceremony execution, signed ceremony results, and
  ceremony-only audit records; superseded where it conflicts with Sign as a special RP.
- `adr/sign-residual-idp-surface-retirement.md` — operational decision to retire the residual
  `sign/id` OIDC provider, `SIGN_*` signing keys, refresh-rotation endpoint, session-mutating
  sign-out paths, and step-up freshness writes; superseded where it conflicts with Sign as a special
  RP and Acme as the only IdP / Authorization Server.

Implementation note: the accepted Acme / Sign / Core / Base / Palm boundary is ahead of parts of the
current code and older plans. Active implementation work is tracked in
`plans/active/acme-sign-core-base-port-implementation.md`; existing Rails-only compatibility routes
or storage do not create a competing ADR-level authority assignment.

Superseded IdP/RP-centered ADRs:

- `adr/split-into-regional-and-global-repos.md`
- `adr/acme-rp-boundary-naming.md`
- `adr/oidc-claims-decision.md`
- `adr/oidc-authn-hardening-implementation-decisions.md`
- `adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`
- `adr/logout-primitive-and-composition.md`
- `adr/session-reset-on-privilege-transition.md`
- `adr/authentication-assurance-level-boundaries.md`
- `adr/step-up-authentication-redesign.md`
- `adr/sign-configuration-sprint-spec.md`
- `adr/sign-up-authentication-handoff-and-social-rt.md`
- `adr/sign-up-cycle-cancellation-retention.md`
- `adr/sign-withdrawal-and-membership-surface-policy.md`
- `adr/cookie-domain-scope-by-surface.md`
- `adr/preference-soft-bubble-doctrine.md`
- `adr/preference-setting-configurator-url-boundaries.md`

Current database naming decisions:

- `adr/actor-db-naming-policy.md`
- `adr/surface-database-connection-naming.md`
- `adr/read-only-content-surfaces-in-rails.md` — current decision for v1 read-only docs/news/help
  content delivery in this Rails repository, including temporary placement in the existing surface
  zenith databases.

Current audit / chronicle decisions:

- `adr/chronicle-audit-db-consolidation.md`
- `adr/chronicle-audit-implementation-guidance.md`

Preference decisions:

- `adr/app-actor-client-naming.md`
- `adr/com-actor-visitor-naming.md`
- `adr/org-actor-operator-naming.md`
- `adr/preference-setting-configurator-url-boundaries.md` — superseded where it assigns preference
  authority outside `acme/www`; retained for historical URL-boundary context.
- `adr/preference-relogin-reconciliation-record-recency.md`
- `adr/preference-extended-option-reference-tables.md`

Current hierarchy / collective decisions:

- `adr/collective-hierarchy-model.md`
- `adr/surface-account-collective-model-naming.md`

Current request-context decisions:

- `adr/actor-current-facade.md`
- `adr/signed-return-targets-only.md`
- `adr/redirect-target-lanes-pt-nt-xt.md` — supersedes the deferred return-target naming direction
  in signed-return-targets-only; current redirect target lanes are `pt`, `nt`, and `xt`.

Current logging / observability decisions:

- `adr/application-logging-boundary.md`
- `adr/non-log-event-reporting-boundary.md` — permits `Rails.event.notify` only for non-log
  observability events, with CSP violation reports as the first in-process subscriber use.
- `adr/traces-and-metrics-routing-via-alloy.md`

Current health / edge access decisions:

- `adr/internal-health-endpoint-edge-isolation.md` — `/health` and every path beneath it are
  internal-only checkpoints blocked at the Cloudflare edge; user-facing availability is served by a
  separate integrated status page (external service).
- `adr/dos-and-firewall-controls-at-cdn-aws-edge-not-in-rails.md` — current source of truth for
  keeping DoS and firewall controls at the CDN/AWS edge instead of in Rails, including CloudFront +
  AWS WAF, ALB origin gating, ECS task ingress, and Rails semantic rate limiting.

Current browser security header decisions:

- `adr/csp-and-permissions-policy.md`
- `adr/csp-violation-report-route-naming.md` — keep `csp_violation_report` route resource naming for
  the `POST /csp-violation-report` endpoint instead of shortening it to bare `csp`.

Current localization decisions:

- `adr/i18n-explicit-translation-keys.md`

Current controller-boundary decisions:

- `adr/two-base-authentication-mode-boundaries.md`
- `adr/static-and-guest-controller-boundaries.md` — deprecated on 2026-05-24 and superseded by the
  two-base authentication mode direction; retained only as historical context.

Sign configuration decisions:

- `adr/authentication-assurance-level-boundaries.md` — partially superseded for authority ownership;
  AAL vocabulary remains useful.
- `adr/finite-nonnegative-rate-limit-counts.md`
- `adr/sign-up-authentication-handoff-and-social-rt.md` — superseded where it assigns session,
  account, or authorization authority to `sign/id`.
- `adr/sign-up-checkpoint-turnstile-boundary.md`
- `adr/sign-up-cycle-cancellation-retention.md` — superseded where it assigns account lifecycle to
  `sign/id`.
- `adr/turnstile-visible-placement-policy.md`
- `adr/sign-withdrawal-and-membership-surface-policy.md` — superseded where it assigns account
  lifecycle to `sign/id`.
- `adr/mfa-reset-account-recovery.md`
- `adr/identifier-hmac-emergency-rotation.md`

Session and token decisions:

- `adr/acme-session-and-token-authority.md`
- `adr/token-lifetime-policy-by-surface.md` — per-surface access/refresh token lifetimes (`app` vs
  `org`); implementation tracked in
  `plans/backlog/token-lifetime-policy-by-surface-implementation.md`.
- `adr/session-token-hardening-baseline.md` — accepted hardening posture for production auth cookies
  (`__Host-`/host-only/Secure/HttpOnly/`SameSite=Strict`/Partitioned), opaque-refresh + JWT-access,
  rotation/reuse/family-revoke, re-issue on security events, server-side timeouts, HSTS, and IP/UA
  as risk signal; implementation tracked in
  `plans/backlog/session-token-hardening-implementation.md`.
- `adr/session-reset-on-privilege-transition.md` — superseded where it assigns session issuance or
  step-up freshness to `sign/id`.
- `adr/logout-primitive-and-composition.md` — superseded where it assigns session authority to
  `sign/id`.
- `adr/device-session-dbsc-device-id-boundary.md` — partially superseded for authority ownership;
  device-session, DBSC, and device-id vocabulary remains useful.

Credential gateway decisions:

- `adr/sign-credential-gateway-surface.md`
- `adr/sign-prefix-routing.md` — partially superseded where it describes `sign/id` as an IdP host;
  retained for historical route-prefix context.

Cookie / session-transport decisions:

- `adr/cookie-domain-scope-by-surface.md` — partially superseded for authority ownership; cookie
  security vocabulary remains useful.

Current tooling / code-quality decisions:

- `adr/ruby-static-analysis-reek-flog-flay.md`

Current outbound delivery decisions:

- `adr/outbound-message-delivery-interface.md`

Current retention / deletion decisions:

- `adr/retainable-concern-and-retention-purge.md`
- `adr/retention-lifecycle-column-boundary.md`

Repository / application boundary decisions:

- `adr/split-into-regional-and-global-repos.md` — superseded where it treats `sign/id` as IdP and
  `acme/www` as RP.
- `adr/acme-rp-boundary-naming.md` — superseded where it treats `acme/www` as an RP boundary instead
  of the identity authority boundary.

Historical engine-era ADRs are retained for traceability only. They do not authorize reintroducing
`engines/`, wrapper apps under `apps/<name>`, `Jit::<EngineName>` namespaces, or `isolate_namespace`
boundaries in this repository.
