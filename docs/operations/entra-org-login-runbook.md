# Entra ID Org login runbook

This runbook covers the human configuration required before enabling the Org Entra login ceremony.
It does not contain credentials or tenant identifiers.

1. Create a Microsoft Entra application registration in the company tenant, for organizational
   accounts only. Do not select an account type that includes personal Microsoft accounts. The org
   surface federates this single tenant (`adr/org-entra-single-tenant-credential-configuration.md`).
2. Register the callback URI `https://<org-auth-host>/social/entra/callback`. This must match
   `ExternalAuthenticationEntraRedirectUri::CALLBACK_PATH` exactly; a mismatch produces AADSTS50011
   at Microsoft. Confirm the host is the Org authentication host, not a request-derived or preview
   host.
3. Create a client secret and store it in Rails credentials as `OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET`.
   Store the directory (tenant) id as `OMNI_AUTH_ENTRA_ORG_TENANT_ID` and the application (client)
   id as `OMNI_AUTH_ENTRA_ORG_CLIENT_ID`. All three are read at boot; a missing one fails the boot
   naming the key. No Entra secret is stored in the database.
4. Add the optional `acct` claim to ID tokens. The Rails verifier requires `acct = 0` and rejects
   guests or tokens without this claim.
5. Review API permissions. The login flow requests `openid profile` only and does not require
   Microsoft Graph permissions. Remove any unnecessary Graph permission added during registration.
6. Pre-provision an active `OperatorEntraIdentity` for each operator, keyed on `tid + oid`. There is
   **no JIT provisioning**: an operator without one cannot sign in. Do not infer an operator from an
   email address, UPN, or domain — only `tid + oid` identifies a person here. **There is currently
   no UI for this**; records must be created directly. Creating them is the last step before first
   sign-in.
7. Perform E2E validation for a pre-provisioned active operator, an unknown identity, a suspended
   identity, cancelled authorization, invalid state, invalid nonce, and kill-switch drain behavior.
8. Test the `social_ceremony_org_entra` kill switch: new ceremonies must stop while a callback for
   an already-issued ceremony is allowed to drain.

The release gate remains incomplete until the production E2E evidence and tenant-specific
administrator-consent evidence are recorded.

## Client secret rotation

1. Create a second client secret on the same Entra application registration. Do not delete the
   existing one yet — Entra allows more than one to be valid at a time.
2. Update `OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET` in Rails credentials to the new value and deploy.
   Never place the secret in the database, source control, fixtures, logs, or this runbook.
3. Keep the old secret valid in Entra during a short overlap window to absorb in-flight
   authorization ceremonies issued before the rotation. Confirm no callback failures reference a
   token-exchange error before proceeding.
4. Delete the old secret in Entra once the overlap window has passed.
5. Record the rotation date and the operator who performed it in the approved secret-management
   boundary, not in this runbook.
