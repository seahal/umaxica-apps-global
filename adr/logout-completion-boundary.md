# Logout Completion Boundary

## Status

Accepted (2026-06-03)

## Context

`adr/identity-authority-boundary.md` and `adr/acme-session-and-token-authority.md` make `acme/www`
the Session and Token Authority. Logout is therefore an acme-owned mutation: acme revokes the
current session, clears auth cookies and Rails session state, records logout audit through the
existing logout primitive, and decides the post-mutation navigation target.

The user-visible post-logout screen still needs a stable place. Showing that screen from `sign/id`
is acceptable only if it does not turn `sign/id` back into a session participant. A one-time
post/redirect/get completion screen on `sign/id` would require `sign/id` to consume session, flash,
or a short-lived completion token. That would make sign responsible for post-logout state and blur
the authority boundary.

## Decision

`acme/www` owns logout completion as a mutation. `sign/id` owns only the logged-out guest entry
screen.

After a successful ordinary logout, acme redirects to a sign-hosted static guest page:

```text
GET /signed-out
```

The legacy sign URL remains a compatibility entry point only:

```text
sign /sign/out -> acme /sign/out
```

The sign completion page is not proof that logout just happened. It is a public, logged-out entry
page that says the user is signed out and offers a link to the sign-in entry point.

## sign/id Signed-Out Page Contract

`sign/id` `/signed-out` must:

- render without requiring an actor or current user;
- avoid session mutation;
- avoid refresh-token reads, writes, rotation, or revocation;
- avoid step-up freshness reads or writes;
- avoid acme token verification;
- avoid logout audit writes;
- link to the surface-local `sign /sign/in` entry point.

Reloading `/signed-out` may show the same page again. This is intentional. A reload-resistant
one-time display is less important than keeping `sign/id` out of post-logout state consumption.

## acme/www Logout Contract

`acme/www` `/sign/out` remains the logout mutation route. It must:

- require the existing CSRF and authentication protections for mutating requests;
- revoke only the current session for ordinary logout;
- clear auth cookies and Rails session state through the logout primitive;
- record the existing logout audit event;
- redirect to the matching sign host's `/signed-out` page after successful ordinary logout;
- avoid user-controlled completion redirects unless an existing signed return-target mechanism
  explicitly authorizes a different destination.

## Consequences

The old sign-side `/sign/out` path can remain as a compatibility redirect because it performs no
logout mutation. The user-visible completion URL is no longer overloaded with the logout execution
URL.

Do not introduce sign-side PRG, flash-backed completion state, session-backed completion notices, or
one-time completion tokens for ordinary logout unless a future ADR explicitly assigns that state to
a different non-session transport that does not make `sign/id` a logout participant.

## Related

- `adr/identity-authority-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/sign-credential-gateway-surface.md`
- `adr/logout-primitive-and-composition.md`
