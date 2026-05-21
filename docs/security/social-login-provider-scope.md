# Social Login Provider Scope

Social login availability is surface-specific.

| Surface | Google   | Apple    |
| ------- | -------- | -------- |
| `app`   | Allowed  | Allowed  |
| `org`   | Allowed  | Rejected |
| `com`   | Rejected | Rejected |

## Rules

- `app` may offer Google and Apple social login for end users.
- `org` may offer Google social login for staff, but must reject Apple social login.
- `com` must not offer or accept any social login provider.
- Direct OmniAuth requests must follow the same surface rules as the UI.
- `org` Google social login is bound through the provider UID stored on `OperatorSocialGoogle`.
  Google email-address matching is not an authentication boundary and must not authorize login.

These rules apply to routes, controllers, views, tests, and provider configuration. Do not add Apple
to `org`, or any social login provider to `com`, without a new accepted ADR.
