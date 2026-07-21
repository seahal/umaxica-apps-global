# Passkey Operations Runbook

## Updating the AAGUID Catalog

- Location: `config/webauthn/aaguid_catalog.yml`, mapping lowercase UUID AAGUID keys to friendly
  names.
- Sources: FIDO Alliance MDS descriptions and the community passkey-authenticator-aaguids list.
- Add an entry, then run
  `bin/rails test test/services/webauthn/authenticator_name_resolver_test.rb`. There is no external
  communication or restart-time dependency; startup does not contact an external service.
- Adding an entry does not change `provider_name` for existing credentials because the value is
  resolved and stored at registration. Design an explicit backfill separately if retrospective
  naming is required; never perform one automatically.

## Unknown AAGUID Values

- Unknown and zero AAGUID values are normal. Registration succeeds, `provider_name` remains NULL,
  the list uses the i18n default ("Passkey" or "My Passkey"), and the detail page displays
  "Unknown authenticator".
- Do not reject registration or warn the user solely because an AAGUID is unknown. It is a
  self-asserted value.

## Duplicate-Registration Support

- "This passkey is already registered" (`InvalidStateError` or HTTP 409) means the same credential
  was submitted again. This is expected defensive behavior. The same authenticator can still create
  a different credential.
- A revoked credential cannot be registered again with the same credential ID. Reusing the same
  physical key requires generating a distinct credential through a new registration.
- Multiple security keys from the same product and multiple passkeys from one provider are valid
  redundancy patterns.

## Limits and Constraints

- Each actor may have at most four passkeys (`MAX_PASSKEYS_PER_*`).
- Registration for a `com` Visitor requires a recovery identity through
  `RecoveryIdentityRequiredValidator`.
- Successful registration tops up recovery passcodes. Newly issued codes are delivered through a
  one-time reveal URL.

## Audit Coverage

- `app` records `ClientChronicleEvent::PASSKEY_REGISTERED`; `org` records
  `OperatorChronicleEvent::PASSKEY_REGISTERED`.
- `com` has no registration audit because its chronicle foundation is incomplete. This is a known
  remaining gap to close when Visitor chronicles are introduced.

## Failure Handling

- Catalog load failures surface on the resolver's first use. Check YAML syntax and inspect
  `Webauthn::AuthenticatorNameResolver.catalog` in the Rails console.
- UV failures such as `UserVerificationRequiredError` or the `uv_rejected` risk event may indicate
  that the client cannot perform UV. The supported fallback is the password sign-in flow.
