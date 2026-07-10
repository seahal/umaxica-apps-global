# Social Login Provider Scope

> **Partially superseded by Identity Authority inversion:** The provider availability vocabulary in
> this document remains useful only where it does not assign account linking, account lifecycle,
> session, token, or freshness authority to `sign/id`. `acme/www` is the Session, Token, Account,
> Preference, Authorization, and downstream-token Authority. `sign/id` is ceremony-only. Existing
> sign-side physical tables/models do not imply sign-side authority. Do not use this document to
> reintroduce sign-side sessions, refresh, preference, dashboard, account lifecycle, token issuance,
> logout, or step-up freshness.

Social login availability is surface-specific.

## Production Target

| Surface | Google   | Apple    | Other external social providers     |
| ------- | -------- | -------- | ----------------------------------- |
| `app`   | Allowed  | Allowed  | Rejected unless accepted separately |
| `org`   | Rejected | Rejected | Rejected                            |
| `com`   | Rejected | Rejected | Rejected                            |

## Rules

- `app` may offer Google and Apple social login for end users.
- `org` must not offer social login. Production org sign-in uses implemented local verifiers only:
  passkey and passcode/secret credential in the current route set. Org TOTP is not current until
  explicit routes, controllers, views, and tests exist.
- `com` must not offer or accept any social login provider.
- Direct OmniAuth requests must follow the same surface rules as the UI.
- On `app`, an unknown Google or Apple identity is a sign-up entry, not a completed login. It must
  go through the sign-up sequence and required checkpoint setup before it can enter the login
  sequence.
- On `app`, a registered Google or Apple identity enters the login sequence. It must not be treated
  as a new sign-up unless required sign-up setup is still incomplete.
- On `app`, a session-limit pending social login resumes at `/sign/in/limitation` with a
  `social_resolution` payload on the Acme surface.
- On `app`, linking Google or Apple from account configuration requires recent token-bound Step-Up
  scope `social_link`. This is separate from `social_unlink`, so a Step-Up completed for one social
  credential operation does not authorize the other.
- Do not add Google, Apple, Microsoft, or any other external social provider to `org` or `com`
  without a new accepted ADR.

## Withdrawn Temporary Gateway

The 2026-06-02 temporary Google gateway exception for `org` and `com` is withdrawn. The old org/com
Google provider IDs and environment flags are not production provider/configuration names. The
cleanup removes their routes, UI, provider registration, temporary provisioners, and retirement
tags. Historical schema cleanup, if needed, requires a separate migration plan.
