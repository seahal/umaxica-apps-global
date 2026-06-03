# Logout Completion Boundary Implementation

## Status

Active implementation plan.

## Summary

Implement the boundary from `adr/logout-completion-boundary.md`: acme performs logout mutation, then
redirects to a static sign guest page at `/signed-out`. Keep legacy `sign /sign/out` redirect-only
to acme. Do not add sign-side one-time PRG completion state for ordinary logout.

## Implementation Changes

- Add surface-local sign routes for `GET /signed-out` on app, com, and org sign hosts.
- Add lightweight sign controllers/actions for `/signed-out` that render as public guest pages and
  do not require actor/current-user state.
- Add signed-out views with only the completion message and a surface-local link to `sign /sign/in`.
- Keep `sign /sign/out` GET/POST/DELETE as compatibility redirects to the matching acme
  `/sign/out` route.
- Change successful ordinary acme logout paths to redirect with `303 See Other` to the matching
  sign host's `/signed-out` URL.
- Retire ordinary logout completion rendering from acme. Acme should not render sign completion
  views after the mutation.
- Remove ordinary logout dependence on session-backed sign-out completion notices where they exist.
  Keep OIDC-specific behavior separate unless a later OIDC logout plan explicitly changes it.

## Guardrails

- `sign/id` `/signed-out` must not read, rotate, revoke, clear, or validate refresh tokens.
- `sign/id` `/signed-out` must not clear Rails session, require current actor, write logout audit,
  or verify acme session/access tokens.
- Completion redirects must be fixed by surface host helpers or existing host mapping logic. Do not
  use a user-controlled `return_to`, `pt`, `rt`, or similar parameter for the default signed-out
  destination.
- Do not convert logout mutation to GET. Mutating acme logout routes must keep CSRF protection.
- Do not add new documentation files in this slice; this plan is the handoff source until the code
  behavior lands.

## Test Plan

- Route tests for `GET /signed-out` on app, com, and org sign hosts.
- Sign controller tests proving `/signed-out` renders without authentication and does not revoke a
  usable token.
- Negative sign tests proving `/signed-out` does not call logout primitives, refresh-token
  mutation, freshness mutation, or logout audit code.
- Existing sign `/sign/out` tests should continue to assert redirect-only behavior and unchanged
  token state for GET, POST, and DELETE.
- Acme logout tests should assert successful POST/DELETE revokes the current token, clears auth
  state through the existing primitive, and redirects to sign `/signed-out`.
- Open-redirect regression tests should assert user-supplied redirect params do not change the
  default signed-out destination.

## Acceptance Criteria

- Ordinary logout flow:

```text
old sign /sign/out
  -> acme /sign/out

acme /sign/out
  -> logout mutation
  -> redirect to sign /signed-out

sign /signed-out
  -> static guest page
  -> sign-in link to sign /sign/in
```

- Reloading `/signed-out` shows the same guest page. This is accepted behavior and not a bug.
- No files outside `adr/` and `plans/` are required for this planning slice.

## Assumptions

- The selected design prioritizes a clean static sign guest page over one-time PRG completion
  display.
- `acme/www` remains the only Session, Token, logout, and logout-audit authority.
- `sign/id` may host logged-out entry pages, but must not become a post-logout state consumer.
