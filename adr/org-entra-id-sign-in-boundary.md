# ADR: Org Entra ID Sign-In Boundary

**Status:** Accepted (2026-06-30)

## Context

Enterprise customers whose staff accounts are managed in Microsoft Entra ID have requested SSO for
the org surface so that a single corporate credential can satisfy the sign-in ceremony. The org
surface currently supports Passkey (WebAuthn) and secret-credential sign-in only. There is no
third-party federated identity entry point.

The Cloudflare Access ADR (`org-cloudflare-access-authentication-layer.md`, 2026-06-29) explicitly
scopes Cloudflare Access to read-only org content (docs/help/info/news). `auth/org`, `base/org`, and
`core/org` continue using full Operator session and credential ceremonies. Entra ID sign-in must
therefore be implemented at the Rails application level as an additional credential ceremony, not at
the edge.

## Decision

### Sign-in only; no provisioning

The Entra ID flow is sign-in only. No Operator record, `OperatorEntraIdentity` record,
`OrganizationEntraConnection` record, or any other principal or membership record is created during
the callback. If a matching pre-provisioned `OperatorEntraIdentity` does not exist, the callback
fails. No JIT provisioning occurs.

### Stable lookup key: `tid + oid`

The only Entra-side identity key used for auth lookup is the combination of:

- `tid` — the Entra tenant ID (a UUID, stable for the lifetime of the tenant)
- `oid` — the Entra object ID (a UUID, stable for the lifetime of the user object in that tenant)

`iss` (derived from `tid`) and `sub` (pairwise pseudonymous, varies by client_id) are stored as
protocol evidence only and are never used for auth lookup.

`email`, `preferred_username`, and `upn` are mutable in Entra. They must not be stored as
identity-determining fields, must not be used as lookup keys or fallback keys, and must not be
requested from Entra. The scope is `"openid profile"` only. `"email"` scope is not requested. The
UserInfo endpoint is never called.

The application registration must emit the optional `acct` claim in ID tokens. Authentication
accepts only `acct = 0`; guest accounts, missing account-type evidence, and personal Microsoft
accounts fail closed.

### Database placement: `org_zenith`

Both `OrganizationEntraConnection` and `OperatorEntraIdentity` are placed in the `org_zenith`
database (base class: `OrgRpRecord`), alongside `OperatorIdentity`. Rationale: both records carry
identity-authority semantics (which tenant is trusted, which `(tid, oid)` pair maps to which
Operator). `org_zenith` is the identity database. `org_principal` is the actor database.
`org_ticket` is the session/token database. Federation records belong with identity, not sessions.

### Why not the existing `operator_identities` table

`OperatorIdentity` uses a generic `(issuer, subject, audience)` key designed for any OIDC IdP.
Entra-specific records require `tid` validation, connection-scoped activation state, and a fixed
`tid + oid` lookup path. Sharing the table would obscure the Entra-specific invariants and couple
the Entra schema to the generic OIDC schema, making independent evolution of either harder. Separate
tables also allow Entra-specific indexes and constraints without affecting the generic OIDC flow.

### OmniAuth is not used on the org surface

`OmniAuthNonAppSocialGuard` (in `config/initializers/omniauth.rb`) blocks all `/social/*` requests
on org and com hosts unconditionally. The `auth_surface :org` route block does not call
`auth_app_social_routes`. The Entra ID flow must not open OmniAuth on org hosts, must not use
`/social` paths, and must not weaken or modify `OmniAuthNonAppSocialGuard`.

### Logical references for `organization_id` and `operator_id`

`OrganizationEntraConnection#organization_id` is a logical reference to `organizations` in
`org_principal`. `OperatorEntraIdentity#operator_id` is a logical reference to `operators` in
`org_principal`. Both are in a different database (`org_zenith` vs `org_principal`), so no enforced
cross-DB foreign key exists. Presence and uniqueness are enforced at the ActiveRecord layer. If
Organization or Operator canonical placement later moves fully into `org_zenith`, the Entra lookup
contract remains unchanged: `tid + oid`.

### Default inactive status

Both `OrganizationEntraConnection` and `OperatorEntraIdentity` default to `status: :inactive`. No
activation occurs automatically. An administrator must explicitly activate each record before it can
be used for sign-in. This is deny-by-default applied at the data layer.

### `operator_id` uniqueness (v1: one Entra identity per Operator)

For v1, `operator_id` is unique across `operator_entra_identities`. One Operator may have at most
one Entra identity mapping. This is intentionally strict. If multi-tenant or multi-provider Operator
mappings are needed in the future, the unique constraint can be loosened and the lookup key adjusted
without changing the `tid + oid` auth contract.

### Certificate credential reference

`OrganizationEntraConnection#entra_credential_key` stores only the name of a Rails credential. The
referenced value contains the certificate and private key PEM. Token exchange uses a short-lived
PS256 `private_key_jwt` assertion with an `x5t#S256` certificate thumbprint. Neither private key nor
client secret is stored in the database.

### Callback boundary

The callback remains `GET /sign/in/entra/callback`. The redirect URI is built from the configured
Org authentication origin and this fixed path; it is never derived from request host, forwarded
host, or referer. The ceremony session holds only an opaque reference. State, nonce, PKCE verifier,
connection reference, and return target are stored server-side, consumed once, and deleted on every
callback outcome, including state mismatch and provider error.

The controller is Rails glue only. `ExternalAuthentication::EntraProviderAdapter` owns code exchange
and token verification. It returns a typed principal containing only verified issuer, pairwise
subject, audience, and typed `tid + oid` context. ID token, access token, token response, raw
claims, profile claims, and AuthHash are discarded at the adapter boundary.

`ExternalAuthenticationOrgEntraCeremonyStore` owns the server-side ceremony reference.
`ENTRA_SOCIAL_CEREMONY_ENABLED` is read only by the provider-availability environment adapter. It
blocks new Org Entra ceremonies when false while allowing already-issued callbacks to drain.

### MFA bypass policy: `entra_id` is not bypassed

Entra ID sign-in does not bypass local MFA. `AuthenticationBase#mfa_bypassed_for_auth_method?`
(`app/controllers/concerns/authentication_base.rb:2858-2860`) returns `true` only for `"passkey"`;
`"entra_id"` falls through to `false`, matching `"secret_credential"`. An external IdP assertion is
not treated as equivalent to local strong evidence of presence. An operator who signs in via Entra
ID and has TOTP enrolled is still required to complete the TOTP step-up before the session is
established. `Auth::Org::Sign::In::Entra::CallbacksController#show`
(`app/controllers/auth/org/sign/in/entra/callbacks_controller.rb:79-84`) calls
`establish_signed_in_session!` with `auth_method: "entra_id"`, which writes `"entra_id"` into the
access token `amr` array and routes through the same session-establishment and MFA-required path as
passkey and secret-credential sign-in. This keeps Entra ID at AAL1 unless and until an explicit
trust policy is introduced for it.

### Scope of this ADR

This ADR covers the data model boundary, identity key decisions, callback boundary, the
no-provisioning guarantee, and the MFA bypass policy above.

## Consequences

- `OrganizationEntraConnection` and `OperatorEntraIdentity` are new models in `org_zenith`.
- Neither model contains an `email`, `upn`, `preferred_username`, or `display_name` column.
- All records default to `:inactive`; sign-in is impossible until explicit activation.
- The callback resolver must be deny-by-default: raise on any miss, never create.
- App Google/Apple social login is unaffected.
- `OmniAuthNonAppSocialGuard` is unmodified.
- `omniauth_openid_connect` remains outside the production Entra path until its real-strategy
  contract tests prove PKCE, state, nonce, signature, issuer, audience, time claims, tenant
  discovery, unknown key handling, token exchange failure, and provider mix-up behavior.
