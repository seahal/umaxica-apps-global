# Active Record Encryption Rotation

This app supports rotating encrypted email and telephone identifiers by keeping the current
encryption key plus an optional previous key chain.

## Configuration

Set the current key in credentials or environment as:

- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`

To keep old ciphertext readable while a rollout is in flight, set:

- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS`

The previous value can be a single string or a JSON array of strings.

## Rotation procedure

1. Generate a new `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`.
2. Move the old value into `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS`.
3. Deploy the config change.
4. Run `bin/rails db:encryption:reencrypt`.
5. Verify the sign-in, OTP, and sign-up paths on `app`, `org`, and `com`.
6. Remove the previous key once the new ciphertext is fully deployed and verified.

## Notes

- The rotation path for email and telephone identifiers relies on the blind-index lookup code in
  `app/models/concerns/email.rb` and `app/models/concerns/telephone.rb`.
- Auth email and telephone identifiers are non-deterministically encrypted. Application lookup code
  must use `find_by_address`, `find_by_number`, `with_address`, `with_number`, or explicit
  `*_digest` queries rather than `find_by(address: ...)` or `find_by(number: ...)`.
- App-side `user_emails` and `user_telephones` store one encrypted identifier column and one HMAC
  digest lookup column (`address_digest` / `number_digest`).
- Keep `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` stable unless you are deliberately changing
  the broader encryption derivation contract.
- Identifier HMAC keys are not Active Record Encryption keys. If `EMAIL_ADDRESS_HMAC_SALT` or
  `TELEPHONE_NUMBER_HMAC_SALT` is exposed, follow
  `docs/security/identifier-hmac-emergency-rotation.md`.
