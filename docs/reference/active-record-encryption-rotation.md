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
- Keep `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` stable unless you are deliberately changing
  the broader encryption derivation contract.
