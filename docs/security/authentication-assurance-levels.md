# Authentication Assurance Levels

This product uses `AAL1`, `AAL2`, and `AAL3` as authentication-boundary terms.

The terminology is inspired by NIST SP 800-63, but this document does not claim strict NIST
conformance. The terms are used so implementation, review, and operations have a shared vocabulary.
No other local AAL levels, such as `AAL0` or `AAL4`, are used.

## Levels

| level  | product meaning                                                                | implementation status |
| ------ | ------------------------------------------------------------------------------ | --------------------- |
| `AAL1` | Baseline signed-in session. Methods that can establish login/session state.    | Current               |
| `AAL2` | Step-up verification for sensitive signed-in actions.                          | Current               |
| `AAL3` | Reserved for highest-impact operational control, such as system-shutdown keys. | Future                |

## AAL1

AAL1 is the normal authentication boundary. A method that can sign an actor in, or maintain a normal
signed-in session, is an AAL1 method.

Current AAL1 sign-in methods are surface-aware:

| surface | AAL1 sign-in methods                                            |
| ------- | --------------------------------------------------------------- |
| `app`   | email OTP, passkey, TOTP, Google social, Apple social, passcode |
| `com`   | email OTP, passkey, passcode                                    |
| `org`   | passkey, Google social, passcode                                |

`passcode` means the current sign-in code path implemented by the existing secret-backed models and
routes.

Email address is not an AAL method by itself. Email functions as AAL1 or AAL2 only when email OTP
verification succeeds.

Telephone is not an AAL method in this product. A telephone number may be used as a personal
identifier, contact identifier, recovery input, or an entry point that starts an AAL1 sign-in flow,
but the telephone credential itself does not satisfy AAL1, AAL2, or AAL3. Knowing the telephone
number can route the actor to an actual verifier, such as TOTP, passcode, or passkey; that verifier
is the AAL method, not possession of the telephone number.

AAL1 does not permit sensitive configuration, credential removal, session revoke-all, withdrawal, or
other actions that require step-up.

## Credential Inventory

Immediate credential counts come from `Authentication::CredentialInventory`.

Actor convenience methods and controller / concern helpers may expose the inventory, but they must
call the same service. Security-sensitive checks, such as deleting an email or telephone, should use
the DB-backed inventory with the candidate credential excluded instead of relying only on a
request-local `Actor` snapshot.

Persisted actor status columns are materialized availability state for coarse gates and routing.
They must be maintained from the same inventory rules and must not introduce separate classification
logic.

### AAL1 Availability State

The actor record should persist whether the actor has any AAL1 credential. The persisted state is a
materialized availability value; immediate deletion checks still use credential inventory.

The AAL1 availability state follows the same reference-value shape as AAL2 availability:

| value | name           | meaning                                                 |
| ----- | -------------- | ------------------------------------------------------- |
| `0`   | `NOTHING`      | Placeholder only. Runtime use is an implementation bug. |
| `1`   | `ACTIVE`       | At least one AAL1 credential exists for the actor.      |
| `5`   | `UNCONFIGURED` | No AAL1 credential exists for the actor.                |

### AAL1 Credential Transitions

| transition | behavior                                                                                                                                                                                                                                                                       |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `0 -> 1`   | Allowed only through explicit entry points. For `Client` and `Visitor`, this is normally sign-up or approved recovery bootstrap. For `Operator`, provisioning or another authorized flow must approve the creation, and ordinary self-service operator creation requires AAL2. |
| `1 -> N`   | Allowed after AAL2 step-up. Specific bootstrap, sign-up, or recovery routes may be explicitly exempted.                                                                                                                                                                        |
| `N -> 1`   | Allowed after AAL2 step-up, provided at least one AAL1 credential remains after removal.                                                                                                                                                                                       |
| `1 -> 0`   | Forbidden from ordinary UI and credential-management flows. Allowed only for account deletion, withdrawal, operator-approved recovery, or explicit destructive administrative processes.                                                                                       |

Removing an AAL1 credential is a sensitive operation. The normal removal path requires recent AAL2
even when the actor will still have one or more AAL1 credentials afterward.

## AAL2

AAL2 is the current step-up boundary. It is used for sensitive signed-in actions and is implemented
through the step-up authentication mechanism.

Current AAL2 methods are surface-aware:

| surface | AAL2 methods             |
| ------- | ------------------------ |
| `app`   | email OTP, passkey, TOTP |
| `com`   | email OTP, passkey       |
| `org`   | passkey                  |

AAL2 method preference is surface-aware. For `app`, prefer phishing-resistant methods first:
passkey, then TOTP, then email OTP.

AAL2 is recent, scoped authentication. A fresh sign-in does not automatically satisfy step-up, and
refreshing an access token returns the session to the default AAL1 context.

Passcodes, social login, and telephone credentials do not count as AAL2 methods.

Step-up scope is exact. A token satisfies a sensitive action only when `last_step_up_scope` matches
the action's required scope and `last_step_up_at` is still within the freshness window. A generic
verification event must not satisfy scoped sensitive actions such as withdrawal, credential removal,
or session revoke-all.

### AAL2 Availability And Freshness

AAL2 has two separate states:

| owner                                                  | state                                   | meaning                                              |
| ------------------------------------------------------ | --------------------------------------- | ---------------------------------------------------- |
| actor (`Client`, `Visitor`, `Operator`)                | `multi_factor_status_id`                | Whether any registered AAL2 credential exists.       |
| token (`ClientToken`, `VisitorToken`, `OperatorToken`) | `last_step_up_at`, `last_step_up_scope` | Whether this session recently completed scoped AAL2. |

The actor availability state must stay true when AAL2 credentials are created, removed, revoked, or
made inactive. Token freshness must remain session-scoped; it must not be stored on the actor,
because one session completing step-up must not elevate every other session.

### AAL2 Credential Transitions

| transition | behavior                                                                                                                                                    |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `0 -> 1`   | Allowed only through the AAL2 bootstrap flow, such as `/verification/setup` leading to email, passkey, or TOTP registration where that method is supported. |
| `1 -> N`   | Allowed only after recent AAL2 step-up.                                                                                                                     |
| `N -> 1`   | Allowed only after recent AAL2 step-up, provided at least one AAL2 credential remains after removal.                                                        |
| `1 -> 0`   | Forbidden from ordinary UI and credential-management flows. Allowed only through the approved MFA reset flow.                                               |

Removing an AAL2 credential requires AAL2 even when other AAL2 credentials remain. Moving from one
registered AAL2 credential to zero is MFA reset account recovery, not ordinary credential
management.

## Personal And Contact Identifiers

Personal identifiers are identifiers used to locate or disambiguate an account candidate during
login. A sign-in flow that requires a personal identifier must not allow login when the actor knows
only an AAL1 verifier but cannot supply the required personal identifier. It also must not allow
login when the actor knows only the personal identifier but cannot satisfy an AAL1 verifier.

Contact identifiers are personal identifiers that can also be used to reach, notify, or recover an
account. Contact identifiers are a subset of personal identifiers. Neither personal identifiers nor
contact identifiers are AAL levels.

Current personal identifiers:

| credential       | personal identifier | contact identifier | AAL relationship                                                                            |
| ---------------- | ------------------- | ------------------ | ------------------------------------------------------------------------------------------- |
| email address    | yes                 | yes                | Not AAL by itself. Email OTP success may satisfy app/com AAL1 or AAL2 depending on context. |
| telephone number | yes                 | yes                | Not AAL1, AAL2, or AAL3. It is an entry point, contact point, or recovery input only.       |
| Google identity  | yes                 | no                 | Google provider authentication may satisfy AAL1 on supported surfaces.                      |
| Apple identity   | yes                 | no                 | Apple provider authentication may satisfy AAL1 on app.                                      |

Current contact identifiers:

| credential       | contact identifier | AAL relationship                                                                            |
| ---------------- | ------------------ | ------------------------------------------------------------------------------------------- |
| email address    | yes                | Not AAL by itself. Email OTP success may satisfy app/com AAL1 or AAL2 depending on context. |
| telephone number | yes                | Not AAL1, AAL2, or AAL3. It is an entry point, contact point, or recovery input only.       |

Ordinary credential-management flows must preserve at least one usable contact identifier after a
removal. Moving from one contact identifier to zero is forbidden from ordinary UI flows. It is
allowed only through account deletion, withdrawal, approved recovery, or explicit destructive
administrative processes.

Contact-identifier deletion is sensitive because it changes the account's notification and recovery
surface. The normal path requires recent AAL2 before deletion, and the deletion guard must evaluate
the post-removal inventory with the credential excluded.

Email deletion may reduce contact identifier count, AAL1 availability, and AAL2 availability at the
same time. Telephone deletion reduces contact identifier count only; it must not be treated as
reducing AAL1, AAL2, or AAL3 availability.

Contact-identifier counts are immediate DB-backed inventory values. They are not token/session
state, and they should not be read from `Actor.authentication`.

## Reverse Lookup

Use this table when deciding which boundary a method belongs to.

| method              | `app`   | `com`       | `org`       | notes                                            |
| ------------------- | ------- | ----------- | ----------- | ------------------------------------------------ |
| email OTP sign-in   | AAL1    | AAL1        | not current | Primary sign-in on app/com.                      |
| email OTP step-up   | AAL2    | AAL2        | not AAL2    | Org email is credential management, not step-up. |
| passkey sign-in     | AAL1    | AAL1        | AAL1        | Sign-in remains AAL1 until explicit step-up.     |
| passkey step-up     | AAL2    | AAL2        | AAL2        | Current phishing-resistant AAL2 method.          |
| TOTP sign-in        | AAL1    | not current | not current | Current only on app.                             |
| TOTP step-up        | AAL2    | not current | not current | Current only on app.                             |
| Google social login | AAL1    | not current | AAL1        | Current on app and org only.                     |
| Apple social login  | AAL1    | not current | not current | Current on app only.                             |
| passcode            | AAL1    | AAL1        | AAL1        | Primary or fallback sign-in code, not step-up.   |
| telephone           | not AAL | not AAL     | not AAL     | Entry point or contact credential only.          |

## AAL3

AAL3 is reserved. It is not implemented.

The intended future use is for operations where AAL2 is not enough, such as approving a key that can
shut down or materially disable the system. AAL3 should be treated as strong authentication plus a
strong approval workflow, not simply as another MFA prompt.

The expected surface for AAL3 is `org`, because the likely use cases are operator-only operational
controls. No app/com AAL3 behavior is planned.

Future AAL3 design should include separate request, approval, and execution steps; non-self
approval; audit logs; notification; and, where appropriate, quorum, cooldown, abort, or rollback
behavior.

## Implementation Notes

- AAL1 inventory answers "can this actor sign in or keep a normal session?"
- AAL2 inventory answers "can this actor satisfy step-up?"
- AAL3 inventory should remain empty or unsupported until a future ADR defines the exact behavior.
- Contact identifier inventory answers "can this account still be reached or recovered through a
  registered contact point?"
- Code and docs should avoid adding non-NIST-inspired product levels such as `AAL0` or `AAL4`.
- Controllers should declare the required assurance boundary and scope, but credential availability
  must be classified through the shared inventory and maintained by model/service lifecycle code.
