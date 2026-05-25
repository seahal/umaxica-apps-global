# Logout Sequence

This document records the current sign-out and logout behavior for the `app`, `com`, and `org` sign
surfaces.

## Ordinary Sign-Out

Ordinary sign-out means "sign out this browser session". It must not revoke every active session for
the actor.

The shared boundary is:

1. `Sign::{App,Com,Org}::OutsController#create` receives the confirmed form submission.
2. `#destroy` validates any signed return target before mutating logout state.
3. `Authentication::Logoutable#logout_current_session!` calls `Authentication::LogoutCurrentSession`
   once.
4. `Authentication::LogoutCurrentSession` creates a surface-local sign-out cycle when it can
   resolve the current token.
5. The sign-out cycle advances through access discard, logical token revoke, expiry wait, and
   completion under the token/session revoke primitive.
6. The logout concern records the current-session audit event when an actor is present.
7. The logout concern always clears auth cookies, clears `Actor`, and resets the Rails session.
8. The controller renders the signed-out page or redirects to a validated return target.

`Authentication::LogoutCurrentSession` is the primitive for one session. Any "all sessions" feature
must be implemented as a separate composition over that primitive.

## Cycle State

Ordinary logout uses the surface-local cycle tables when a current token is available:

- `ClientSignOutCycle` for `app`
- `VisitorSignOutCycle` for `com`
- `OperatorSignOutCycle` for `org`

The state order is fixed:

```text
REQUESTED
-> ACCESS_DISCARDED
-> LOGICALLY_REVOKED
-> AWAITING_EXPIRY
-> COMPLETED
```

`FAILED` is terminal and is used only if the revoke primitive raises after a cycle has started.
Reverse transitions are rejected by the cycle model. A stale unauthenticated submission does not
create a cycle because it has no authenticated current token to bind.

## Result Contract

Current-session logout returns a `Logout::Result` shape so controllers can map logout state to HTTP
responses without reimplementing token mutation.

Supported current-session statuses:

- `success`: the current token was processed through the logout primitive.

This state renders the signed-out page with `200 OK` when there is no valid return target.
If the token is already revoked but still resolvable, the primitive remains idempotent and records a
completed sign-out cycle for that authenticated request.

## Stale Tab Submissions

`POST /sign/out` and `DELETE /sign/out` require the browser to still be authenticated. This covers
the stale-tab case without pretending that logout ran twice:

1. Tab A displays the sign-out confirmation.
2. Tab B displays the sign-out confirmation.
3. Tab B submits sign-out and completes logout.
4. The browser receives cleared auth cookies and a reset Rails session.
5. Tab A still displays the old sign-out form.
6. Tab A submits the form.
7. `authenticate!` rejects the request and redirects to sign-in with an authentication return target
   pointing back to `/sign/out`.

The stale-tab path does not call the token revoke primitive, does not write a logout audit event,
and does not render the signed-out page, because the browser no longer has the access/refresh cookie
state required to prove an authenticated logout request.

Unauthenticated `GET /sign/out/edit` is protected by the same `authenticate!` boundary.

## Example

For the `app` surface:

1. Tab A opens `https://id.umaxica.app/sign/out?ri=jp`.
2. Tab B opens `https://id.umaxica.app/sign/out?ri=jp`.
3. Tab B posts the form and receives the signed-out page.
4. The browser receives cleared auth cookies and a reset Rails session.
5. Tab A posts the stale form and is redirected to `/sign/in?...rt=...`; it does not receive the
   signed-out page.

## Return Targets

Signed return targets are resolved before a successful authenticated logout. Invalid or legacy
return targets fail closed after the current session is revoked.

A stale unauthenticated submission does not consume a return target because the request is no longer
authenticated and cannot prove the original logout state.

## Tests

Primary regression coverage lives in:

- `test/controllers/sign/app/outs_controller_test.rb`
- `test/controllers/sign/com/outs_controller_test.rb`
- `test/controllers/sign/org/outs_controller_test.rb`
- `test/controllers/concerns/authentication/logoutable_test.rb`
- `test/controllers/concerns/authentication/logout_current_session_test.rb`
- `test/controllers/concerns/authentication/logout_all_sessions_test.rb`
