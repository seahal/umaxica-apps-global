# Entra ID Org login runbook

This runbook covers the human configuration required before enabling the Org Entra login ceremony.
It does not contain credentials or tenant identifiers.

1. Create a Microsoft Entra application registration for organizational accounts only. Do not select
   an account type that includes personal Microsoft accounts.
2. Register the fixed callback URI ending in `/sign/in/entra/callback`. Confirm that the configured
   host is the Org authentication host, not a request-derived or preview host.
3. Upload the public certificate and store its private key and certificate PEM under a dedicated
   Rails credential key. Store only that key name in `OrganizationEntraConnection#entra_credential_key`.
   Do not create or store a client secret.
4. Add the optional `acct` claim to ID tokens. The Rails verifier requires `acct = 0` and rejects
   guests or tokens without this claim.
5. Review API permissions. The login flow requests `openid profile` only and does not require
   Microsoft Graph permissions. Remove any unnecessary Graph permission added during registration.
6. Pre-register each approved tenant as an active `OrganizationEntraConnection`. Associate
   pre-provisioned `OperatorEntraIdentity` records using `tid + oid`. Do not infer an organization
   or an operator from an email address, UPN, or domain. Pre-registration is performed through the
   operator settings surface at `auth/org/settings/entras`
   (`Auth::Org::Settings::EntrasController`); it does not accept email, UPN, or domain input, only
   `tid + oid`.
7. Verify whether each customer tenant requires administrator consent under its tenant policy.
   Complete that consent through the customer's approved process.
8. Perform production E2E validation for a pre-provisioned active operator, unknown tenant, unknown
   identity, cancelled authorization, invalid state, invalid nonce, and kill-switch drain behavior.
9. Test `ENTRA_SOCIAL_CEREMONY_ENABLED=false`: new ceremonies must stop while a callback for an
   already-issued ceremony is allowed to drain.

The release gate remains incomplete until the production E2E evidence and tenant-specific
administrator-consent evidence are recorded.

## Certificate rotation

1. Create a new certificate and upload its public half to the same Entra application registration.
   Do not remove the existing certificate yet.
2. Store the new certificate and private key under a new Rails credential key, then update
   `OrganizationEntraConnection#entra_credential_key` to that reference. Never place private key
   material in the database, source control, fixtures, logs, or this runbook.
3. Keep the old credential valid in Entra during a short overlap window to absorb in-flight
   authorization ceremonies that were issued before the rotation. Confirm no callback failures
   reference the old credential before proceeding.
4. Remove the old certificate in Entra once the overlap window has passed and no callback
   failures reference it.
5. Record the rotation date and operator who performed it in the approved secret-management
   boundary, not in this runbook.
