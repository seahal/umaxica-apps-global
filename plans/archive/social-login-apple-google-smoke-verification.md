# Social Login (Google + Apple) Smoke Verification

## Goal

Run a smoke / E2E checklist against the **already-shipped** Google and Apple Sign In implementations
and repair any defect that surfaces. No new features.

## Status

**Implemented / verified 2026-05-10.** The smoke regression suite surfaced a callback guard
regression where optional `state` / `provider` reads used `params.expect`, turning mocked OAuth
callbacks without query state into `403 bad_state` responses. The guard now uses non-raising
parameter reads for optional callback data while preserving strict-state tests via
`X-STRICT-SOCIAL-STATE`.

## Background

User asked whether Apple Sign In is ready and whether Google's restoration is solid. Investigation
(2026-05-09):

- Apple Sign In is fully implemented:
  - `config/initializers/omniauth.rb:145-169` — Apple OIDC id_token flow.
  - `app/models/user_social_apple.rb` — identity / status model.
  - `app/services/social_auth_service.rb:142-192` — Apple uid fallback extraction.
  - 12 social-login integration tests including `test/integration/apple_auth_test.rb`,
    `apple_social_flows_test.rb`.
- Google Sign In is fully implemented for both `google_app` (user) and `google_org` (staff) clients
  (`omniauth.rb:104-133`).
- The `com` surface intentionally blocks social login per `adr/sign-com-no-social-login.md`; this is
  asserted by `com_social_login_blocked_test.rb`.

The previously deferred follow-up was "add regression tests but tokens were insufficient." That
sub-task is included here as an open question — confirm whether OmniAuth `mock_auth` covers the gap
or whether dev Apple credentials are needed.

## Verification Checklist

### Google (`app` surface)

1. `app.localhost` → click "Sign in with Google".
2. Successful flow creates a fresh `User` with linked `UserSocialGoogle` (status = ACTIVE).
3. Sign out, sign back in — identity link is preserved, no duplicate user.
4. Auto-link path: while logged in, hit the Google callback again — second `UserSocialGoogle` is
   **not** created; existing identity is reused (`omniauth_callbacks_controller.rb:376-398`).
5. Tampered `state` parameter → callback rejected (4xx). Asserted by
   `social_callback_guard_test.rb`.

### Google (`org` surface)

6. `org.localhost` → staff login via the `google_org` OAuth client.
7. Verify the per-surface client allowlist actually routes to `google_org`, not `google_app`.

### Apple (`app` surface)

8. `app.localhost` → "Sign in with Apple".
9. Apple returns id_token; uid is extracted via the fallback path (`SocialAuthService:142-192`) when
   `info.email` is absent.
10. Successful flow creates `User` + `UserSocialApple` (status = ACTIVE).
11. Re-login preserves the identity link.

### `com` surface block

12. `com.localhost` → social-login affordance is absent / blocked. ADR `sign-com-no-social-login.md`
    invariant holds.

## Critical Files

- `config/initializers/omniauth.rb:104-169` — provider configuration.
- `app/services/social_auth_service.rb` — login / link / reauth orchestration.
- `app/controllers/sign/app/auth/omniauth_callbacks_controller.rb` — callbacks.
- `app/models/user_social_google.rb`, `app/models/user_social_apple.rb`.
- Test fixtures: `test/fixtures/user_social_{apples,googles}.yml`.
- Integration tests: `test/integration/apple_auth_test.rb` and 11 sibling files.

## Open Question

- "Tokens insufficient" follow-up: confirm whether the gap is mocked-auth fixtures
  (`OmniAuth.config.mock_auth` is enough) or real Apple Sign In credentials in dev (Apple developer
  account, key, team id, etc.) needed for regression coverage. If the latter, file a separate plan
  rather than blocking this one.

## Verification

- `bin/rails test test/integration/{apple_auth,social_auth_login,social_auth_reauth, social_auth_unlink,social_auth_state,social_callback_guard,com_social_login_blocked, social_login_robustness}_test.rb`
- Manual: every checklist item above against a dev environment.

2026-05-10 automated verification:

- `bin/rails test test/integration/apple_auth_test.rb test/integration/apple_social_flows_test.rb test/integration/social_auth_login_test.rb test/integration/social_auth_reauth_test.rb test/integration/social_auth_unlink_test.rb test/integration/social_auth_state_test.rb test/integration/social_callback_guard_test.rb test/integration/com_social_login_blocked_test.rb test/integration/social_login_robustness_test.rb test/integration/social_auth_auto_link_test.rb test/integration/app_social_login_works_test.rb`
  passed: 67 runs, 256 assertions.

## Out of Scope

- Adding new social providers.
- Adding social login to the `com` surface — ADR forbids it.
- Refactoring `SocialAuthService`.

## Related

- `adr/sign-com-no-social-login.md` — `com` block.
- `plans/backlog/social-login-implementation-plan.md` — historical aspirational design; current
  implementation is leaner. Treat as historical only.
