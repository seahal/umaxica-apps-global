# Logout Completion Boundary

## Status

Accepted (2026-06-03)

## Context

`adr/identity-authority-boundary.md` and `adr/acme-session-and-token-authority.md` make `acme/www`
the Session and Token Authority. Logout is therefore an acme-owned mutation: acme revokes the
current session, clears auth cookies and Rails session state, records logout audit through the
existing logout primitive, and decides the post-mutation navigation target.

The user-visible post-logout screen still needs a stable place. The completion result may be shown
only once, and the result display must be consumed from a session-bound marker so a stale or
replayed completion URL cannot keep displaying logout success.

## Decision

`acme/www` owns logout completion as a mutation. `sign/id` owns only the logged-out guest entry
screen.

After a successful ordinary logout, acme redirects to a sign-hosted completion page that is consumed
once:

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

Reloading `/signed-out` must fail closed after the completion marker has been consumed. The browser
may revisit the URL, but the server must not re-display a successful logout result from stale or
reused state.

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
URL, but it is still one-time and session-bound.

Do not introduce sign-side PRG, flash-backed completion state, or reusable completion URLs for
ordinary logout. Flash is in any case removed application-wide; see
`.agents/harnesses/rules/generic/no-flash-messages.mdc`.

## Related

- `adr/identity-authority-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/sign-credential-gateway-surface.md`
- `adr/logout-primitive-and-composition.md`
