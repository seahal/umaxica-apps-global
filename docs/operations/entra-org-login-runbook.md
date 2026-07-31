# Entra ID Org login runbook

This runbook covers the human configuration required before enabling the Org Entra login ceremony.
It does not contain credentials or tenant identifiers.

1. Create a Microsoft Entra application registration for organizational accounts only. Do not select
   an account type that includes personal Microsoft accounts.
2. Register the fixed callback URI ending in `/sign/in/entra/callback`. Confirm that the configured
   host is the Org authentication host, not a request-derived or preview host.
3. Record the application client ID and create an application credential in the approved
   secret-management boundary. Never place its value in source control, fixtures, logs, or this
   runbook.
4. Review API permissions. The login flow requests `openid profile` only and does not require
   Microsoft Graph permissions. Remove any unnecessary Graph permission added during registration.
5. Pre-register each approved tenant as an active `OrganizationEntraConnection`. Associate
   pre-provisioned `OperatorEntraIdentity` records using `tid + oid`. Do not infer an organization
   or an operator from an email address, UPN, or domain. Pre-registration is performed through the
   operator settings surface at `auth/org/settings/entras`
   (`Auth::Org::Settings::EntrasController`); it does not accept email, UPN, or domain input, only
   `tid + oid`.
6. Verify whether each customer tenant requires administrator consent under its tenant policy.
   Complete that consent through the customer's approved process.
7. Perform production E2E validation for a pre-provisioned active operator, unknown tenant, unknown
   identity, cancelled authorization, invalid state, invalid nonce, and kill-switch drain behavior.
8. Test `ENTRA_SOCIAL_CEREMONY_ENABLED=false`: new ceremonies must stop while a callback for an
   already-issued ceremony is allowed to drain.

The release gate remains incomplete until the production E2E evidence and tenant-specific
administrator-consent evidence are recorded.

## Client secret rotation

1. Create a new application credential for the same Entra application registration in the approved
   secret-management boundary. Do not remove the existing credential yet.
2. Update `OrganizationEntraConnection#entra_client_secret` for the affected connection to the new
   value through the approved secret-management process. The column is encrypted at rest
   (`encrypts :entra_client_secret`); never place the plaintext value in source control, fixtures,
   logs, or this runbook.
3. Keep the old credential valid in Entra during a short overlap window to absorb in-flight
   authorization ceremonies that were issued before the rotation. Confirm no callback failures
   reference the old credential before proceeding.
4. Revoke the old application credential in Entra once the overlap window has passed and no callback
   failures reference it.
5. Record the rotation date and operator who performed it in the approved secret-management
   boundary, not in this runbook.
