# Step-Up Ceremony Delegation

## Boundary

Step-up has two separate parts:

- `sign/id` executes the credential ceremony.
- `acme/www` owns the session-bound freshness decision and storage.

`sign/id` must not store `recent_auth`, `sudo`, `last_step_up_at`, AAL freshness, or equivalent
session freshness. A successful sign ceremony is evidence only until acme consumes the signed
ceremony result.

## Flow

1. `acme/www` decides that a sensitive action requires step-up.
2. `acme/www` issues a ceremony grant for the required purpose and session.
3. `sign/id` executes the allowed credential ceremony.
4. `sign/id` returns a signed ceremony result.
5. `acme/www` validates and consumes the result.
6. `acme/www` commits or rejects step-up freshness for the session.

## Non-Goals

- Do not treat credential registration as step-up freshness.
- Do not let policy code perform ceremony side effects.
- Do not use redirects or return targets as proof that step-up succeeded.

## Related

- `docs/security/authentication-assurance-levels.md`
- `docs/security/ceremony-grant-result.md`
