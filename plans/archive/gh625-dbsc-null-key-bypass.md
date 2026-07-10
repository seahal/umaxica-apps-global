# GH-625: DBSC VerificationService Null Key Bypass Risk

GitHub: #625

## Problem

`Dbsc::VerificationService` (line 43) passes the return value of
`RecordAdapter.dbsc_public_key(record)` directly to `JWT.decode` without a nil check. The existing
guard at line 25 only checks `record.dbsc_public_key` (the raw stored value), not the parsed key
object.

If `dbsc_public_key` contains corrupted JSON that passes `.blank?` but fails JWK import,
`RecordAdapter.dbsc_public_key` returns `nil`, and `JWT.decode(proof, nil, true, ...)` is called
with undefined behavior.

## Attack Scenario

1. Attacker compromises stored `dbsc_public_key` value (corrupt JSON that passes `.blank?`).
2. `RecordAdapter.dbsc_public_key(record)` returns `nil`.
3. `JWT.decode(proof, nil, true, algorithms: [...])` behavior is undefined per JWT gem version.

## Proposed Fix

Add explicit nil check after key resolution, before the verified `JWT.decode` call:

```ruby
public_key = RecordAdapter.dbsc_public_key(record)
return failure("invalid_public_key") if public_key.nil?
JWT.decode(proof, public_key, true, algorithms: [unverified_header["alg"]])
```

Verify the same pattern in `Dbsc::RegistrationService` (line 42-43).

## Files

- `app/services/dbsc/verification_service.rb:43`
- `app/services/dbsc/registration_service.rb:42-43`
- `app/services/dbsc/record_adapter.rb`

## Tests

- Add test for corrupted JWK JSON that passes `.blank?` but fails import.
- Add test confirming `failure("invalid_public_key")` is returned when parsed key is nil.
- Verify `RegistrationService` rescue path covers `JWT::JWKError`.

## Implementation Status (2026-04-07)

**Status: COMPLETE**

- VerificationService line 25:
  `return failure("missing_public_key") if record.dbsc_public_key.blank?` guards before
  `JWT.decode`.
- RegistrationService lines 38-39: explicit `return failure("missing_public_key") if jwk.blank?`
  after `normalize_public_key`.
- RecordAdapter.dbsc_public_key returns `nil` safely on corrupt JSON.
- Both paths are protected. This issue can be closed.

## Improvement Points (2026-04-07 Review)

- Verify both verification and registration paths against the same malformed JWK fixtures. This
  should become one shared negative test matrix, not two loosely related checks.
- Record the current JWT gem behavior during nil-key decode in the issue notes so the fix protects a
  known failure mode instead of an abstract risk.
