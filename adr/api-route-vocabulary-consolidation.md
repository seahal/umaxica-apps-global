# API Route Vocabulary Consolidation Toward `/api/v0`

**Status:** Accepted (2026-06-13)

> This ADR records a route-naming direction only. It changes no routes, controllers, helpers, or
> runtime behavior. Implementation is deferred to later, separately reviewed work.

## Status

Accepted (2026-06-13).

This decision establishes preferred long-term vocabulary for API route namespaces. It is a naming
and direction decision, not an implementation. No routes are added, removed, redirected, or aliased
by recording this ADR.

## Context

The repository currently exposes versioned machine-facing endpoints under two separate top-level
route namespaces, both at version `v0`.

Observed facts (from `config/routes/*.rb` and route comments as of 2026-06-13):

- `web/v0` namespaces exist in `config/routes/acme.rb`, `config/routes/core.rb`, and
  `config/routes/sign.rb`. The route comment labels them `Public web API` (acme, sign) and they
  carry `cookie` (show/update), `theme` (show/update), and — in `sign.rb` only — OTP delivery
  (`web/v0/in/email/otp`, `web/v0/in/telephone/otp`, both `create`).
- `edge/v0` namespaces exist in `config/routes/acme.rb`, `config/routes/core.rb`,
  `config/routes/sign.rb`, `config/routes/docs.rb`, `config/routes/help.rb`, and
  `config/routes/news.rb`. The route comment labels them `Edge API` /
  `Edge API: token lifecycle management`. They carry: token lifecycle (`edge/v0/token/check`,
  `edge/v0/token/dbsc`, `edge/v0/token/refresh`), preference (`edge/v0/cookie`, `edge/v0/dbsc`), and
  content reads (`edge/v0/entries`, index/show, under docs/help/news).
- No `api/v0` namespace exists anywhere in the repository today (repo-wide search returned no
  matches).

The names `web` and `edge` originate from differing historical implementation assumptions about how
each endpoint group would be served. For API clients, the distinction these names encode is no
longer a useful stable boundary: from a client's perspective, both namespaces are simply API
endpoints. The split also makes `v0` versioning ambiguous, because the same version number lives
under two unrelated prefixes.

UNKNOWN: the precise client mapping for each namespace (for example, which endpoints are consumed by
browser fetch versus an iOS or other native client) is not established by route definitions alone
and is not asserted here. The route comments state intent (`Public web API`, `Edge API`) but do not
prove a per-client mapping.

## Decision

`/api/v0` is the preferred long-term namespace for the application's API routes.

`/web/v0` and `/edge/v0` are treated as legacy / transitional API route vocabulary. Future API
routes, and future migrations of existing API routes, should converge toward `/api/v0/...` as the
canonical namespace.

This is a vocabulary decision only. No routes are changed in this task.

### Classification rule

The convergence applies to _actual API endpoints_. Protocol, ceremony, and operational endpoints are
not blindly moved under `/api/v0`. Whether a given endpoint is an "actual API endpoint" for the
purpose of this rule must be decided per endpoint during later, separately reviewed migration work.

## Scope

In scope for this decision:

- The naming of API route namespaces.
- The direction that API route namespaces should consolidate under `/api/v0`.
- The future migration direction from `/web/v0` and `/edge/v0` toward `/api/v0`.
- Documenting compatibility requirements that future migration must satisfy.
- Documenting that any actual implementation must happen later.

## Non-scope

This decision does not cover and does not authorize:

- Controller, model, migration, or test changes.
- Any route addition, deletion, redirect, alias, or compatibility shim.
- Changes to route helpers or path helper names.
- API response schema changes.
- Frontend ownership, content-surface design, or HTML rendering concerns.
- Integration decisions for any specific runtime or framework.

The following existing route categories are **not** automatically part of this decision and may
remain outside `/api/v0` unless a later ADR explicitly moves them:

- `/auth/...` (including OAuth/OIDC callback and OmniAuth callback routes).
- `/sso/...`.
- `/.well-known/...`.
- `/health/...` and its liveness/readiness/startup children.
- Browser ceremony routes (for example the sign-in / sign-up flow routes).
- Human-facing HTML routes.

## Consequences

- A single canonical API namespace (`/api/v0`) gives clients one stable vocabulary and removes the
  `web` versus `edge` distinction, which no longer carries useful meaning for API consumers.
- Because nothing is implemented here, current clients and tests that reference `/web/v0/...` and
  `/edge/v0/...` continue to work unchanged. There is no immediate compatibility impact.
- Future migration work will need to reconcile a large existing surface: `/web/v0` and `/edge/v0`
  paths are referenced across JavaScript controllers, controller concerns, and tests, so any actual
  move is a cross-cutting change requiring its own plan and review.
- The per-endpoint classification rule means migration is not mechanical; each endpoint must be
  judged as an actual API endpoint versus a protocol/ceremony/operational endpoint before it is
  considered for `/api/v0`.

## Compatibility requirements

These requirements constrain any _future_ implementation; they are not actions taken in this task.

- Future route migration requires a compatibility review before any path changes.
- Future route migration may require redirects, aliases, or dual route support (serving both the
  legacy and the `/api/v0` path) to avoid breaking existing clients.
- `/web/v0` and `/edge/v0` must not be removed as part of recording this decision, and must not be
  removed by future work until compatibility review confirms it is safe.
- Protocol and operational endpoints (see Non-scope) are not automatically moved to `/api/v0`.

## Future implementation notes

- Implementation must happen later, under its own plan and review, and is explicitly out of scope
  here.
- A future migration should begin by classifying each existing `web/v0` and `edge/v0` endpoint as an
  actual API endpoint or a protocol/ceremony/operational endpoint, then migrating only the former.
- The content-read endpoints `/edge/v0/entries` (docs/help/news) are an open classification question
  and require separate review before any decision; they are intentionally not classified here.
- Exploratory implementation notes, the candidate-route inventory, risks, and open questions are
  recorded in `memos/2026-06-13-claude-api-route-vocabulary-consolidation.md`.
