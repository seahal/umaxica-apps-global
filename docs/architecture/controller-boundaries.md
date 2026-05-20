# Controller Boundaries

The application uses four semantic controller boundaries for `sign` and `apex` controllers.
Inheritance should make the request access contract readable before the controller body is
inspected.

For `sign`, these boundaries are surface-local: `Sign::App::*Controller`, `Sign::Com::*Controller`,
and `Sign::Org::*Controller` own their own base classes so `app`, `com`, and `org` behavior stays
separated.

## The Four Boundaries

### OpenController

Use `OpenController` for endpoints that are reachable with or without a signed-in actor.

Open controllers may inspect session, preference, authentication, actor, and current-context state
when it exists. They must not require a signed-in actor by default.

Common examples:

- sign-in continuation endpoints;
- preference endpoints that can work anonymously and can bind to a signed-in actor;
- public-facing pages that personalize for signed-in actors.

### BareController

Use `BareController` for endpoints that do not implement application authentication.

Bare controllers should not read actor, current-context, preference, authorization, verification, or
authentication pipeline state. They may use minimal Rails behavior such as CSRF protection, browser
constraints, and narrow rate limiting when needed.

Common examples:

- health endpoints;
- robots endpoints;
- sitemap endpoints;
- public infrastructure endpoints with no actor semantics.

### PrivateController

Use `PrivateController` for endpoints that require an authenticated actor.

Private controllers run the full surface pipeline for authentication, verification, authorization,
preferences, current actor setup, and request finishing in the established order.

Common examples:

- dashboards;
- account configuration;
- credential management;
- authenticated APIs tied to the current actor.

### GuestController

Use `GuestController` for flows that authenticated actors must not enter.

Guest controllers are for sign-in, sign-up, credential entry, and similar pages where an already
signed-in actor should be rejected or redirected according to the surface behavior.

## ApplicationController

`ApplicationController` is a Rails compatibility parent, not a semantic boundary.

Rails generators create new controllers under `ApplicationController`. That is acceptable as a
starting point, but completed controller work should move to `OpenController`, `BareController`,
`PrivateController`, or `GuestController` unless the controller is listed as a documented exception.

## Etc: Temporary Exceptions

Some security-sensitive controllers are not yet migrated directly to the four boundary bases. These
are temporary exceptions, not a fifth category.

An exception is allowed only when a controller needs additional guard state that should first be
captured by a named derivative of one of the four bases.

Current exception families:

- social authentication controllers that currently combine open entry actions with private unlink
  actions requiring step-up verification;
- session-limit gate controllers that are open to a pending or restricted login flow but reject
  ordinary active sessions;
- OAuth and OIDC callback controllers protected by provider state, callback guard, PKCE verifier,
  nonce, or session state;
- OAuth token exchange endpoints that use `null_session` and protocol-level client authentication
  instead of actor authentication;
- edge token, DBSC, and preference endpoints that are open but intentionally use only selected
  cookie, token, DBSC, and preference pipeline behavior.

Preferred retirement paths:

- split mixed Open/Private controllers by action boundary;
- introduce `OpenController` derivatives for callback, session-gate, and edge endpoints;
- introduce a `BareController` derivative for token exchange endpoints if they remain independent of
  actor, preference, authorization, and verification state;
- keep surface behavior local to `app`, `com`, and `org` unless an existing shared concern already
  provides a safe abstraction.

When an exception is migrated, keep the security checks intact: CSRF behavior, callback state,
nonce, DPoP, DBSC challenge, session-limit gate, restricted-session handling, and step-up
verification must not be removed as an inheritance side effect.
