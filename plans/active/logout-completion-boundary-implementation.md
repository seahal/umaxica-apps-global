# Logout Completion Boundary Implementation

## Status

Active implementation plan, updated by the current Identity Authority boundary.

## Summary

Sign owns logout mutation, refresh/session-token revocation, logout audit, and logout completion
state. Acme may initiate logout or consume a Sign logout result, but Acme must not perform durable
logout mutation directly.

## Implementation Changes

- Add or retain surface-local sign routes for logout mutation and `GET /signed-out` on app, com, and
  org sign hosts.
- Route logout mutation through a Sign logout/session authority service rather than controller-level
  token primitives.
- Add lightweight sign controllers/actions for `/signed-out` that render as public guest pages and
  do not repeat logout mutation.
- Add signed-out views with only the completion message and a surface-local link to `sign /sign/in`.
- Change acme logout entry points to compatibility redirect or JumpRT delegation to the matching
  sign logout authority route.
- Retire ordinary logout mutation and completion rendering from acme.
- Keep OIDC/RP-specific logout behavior separate unless a later external RP/OIDC plan explicitly
  changes it.

## Guardrails

- Sign logout mutation must keep CSRF protection and must not be converted to `GET`.
- Sign logout mutation must be idempotent and should return a durable result object for Acme or UI
  consumption.
- Sign logout authority should read, rotate, revoke, clear, or validate refresh/session-token state
  only through explicit logout/session authority services.
- `sign/id` `/signed-out` must not repeat logout mutation after the Sign authority result is
  committed.
- Acme logout compatibility endpoints must not revoke refresh tokens, clear auth cookies, reset
  Rails session, write logout audit, or inspect logout attempt state directly.
- Completion redirects must be fixed by surface host helpers or existing host mapping logic. Do not
  use a user-controlled `return_to`, `pt`, `rt`, or similar parameter for the default signed-out
  destination.
- Do not add new documentation files in this slice; this plan is the handoff source until the code
  behavior lands.

## Test Plan

- Route tests for Sign logout mutation and `GET /signed-out` on app, com, and org sign hosts.
- Sign controller/service tests proving logout revokes the current token/session state through the
  Sign authority service and is idempotent.
- Sign controller tests proving `/signed-out` renders without authentication and does not revoke a
  usable token.
- Negative acme tests proving acme logout compatibility endpoints do not call logout primitives,
  refresh-token mutation, session reset, or logout audit code directly.
- Open-redirect regression tests should assert user-supplied redirect params do not change the
  default signed-out destination.

## Acceptance Criteria

- Ordinary logout flow:

```text
old acme /sign/out or old sign /sign/out compatibility URL
  -> sign logout authority
  -> logout mutation
  -> redirect to sign /signed-out

sign /signed-out
  -> static guest page
  -> sign-in link to sign /sign/in
```

- Reloading `/signed-out` shows the same guest page and does not repeat logout mutation.
- No files outside `adr/` and `plans/` are required for this planning slice.

## Assumptions

- The selected design prioritizes a clean static sign guest page over one-time PRG completion
  display.
- `sign/id` remains the Refresh, Logout, session-token revocation, and logout-audit authority.
- `acme/www` may initiate logout or consume logout results, but must not become the durable logout
  mutation owner.
