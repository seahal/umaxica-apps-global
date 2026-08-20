# API Versioning and Client Conventions Without Governing Standards

**Status:** Accepted (2026-08-16)

## Status

Accepted (2026-08-16).

**None of the four areas below is governed by a published standard.** Each is either a de facto
industry practice, an unpublished IETF draft, or a specification maintained outside the IETF. They
are recorded here rather than in `docs/reference/api-design-standards.md`, which carries only
rules with a published specification behind them.

Specification status was verified against the IETF Datatracker on 2026-08-16 and is restated below,
because two of these areas are commonly — and incorrectly — described as standards.

## Context

The repository exposes versioned endpoints under three parallel namespaces at the same version
number: `/api/v0`, `/edge/v0`, and `/web/v0`. `adr/api-route-vocabulary-consolidation.md` (Accepted
2026-06-13) selected `/api/v0` as the canonical namespace but recorded no versioning *policy* — what
`v0` promises, what forces `v1`, and how a retired version is announced.

Related current facts:

- `Deprecation` and `Sunset` header emission does not exist anywhere in the repository.
- `app/controllers/concerns/rate_limit.rb:19-20` emits `X-RateLimit-Layer` and `X-RateLimit-Rule`,
  neither of which is a registered or drafted field name, and both of which disclose internal
  enforcement structure.
- `POST /api/v0/token/refresh`
  (`app/controllers/core/{app,com,org}/api/v0/token/refreshes_controller.rb`) consumes and rotates a
  refresh credential with no retry-safety mechanism. A network-level retry loses the credential.
- `public/openapi.yml` is 100 lines describing a single path, `/v0/health`, which **the router does
  not serve** — the real routes are `/health` and `/health/{liveness,readiness,startup}`
  (`config/routes/docs.rb:17-22`). Its `Error` schema `{error, message, details}` matches no
  controller output, and its `servers` list contains only `*.localhost` hosts.

## Decision

### 1. Versioning: path-based major versions

`/api/v{n}`, continuing the existing form. Date-based versioning with a header selector — the model
GitHub, Stripe, and Shopify use — was considered and **rejected**: it exists to let a large
third-party developer population upgrade independently, and it imposes per-version response
transformation machinery. This API's consumers are first-party (the Next.js edge applications and the
native client). If a broad third-party public API is ever offered, that is a new decision, not an
extension of this one.

`v0` means the contract is not frozen. Declaring `v1` is a deliberate act that commits to the
deprecation policy in `docs/reference/api-design-standards.md`.

A new major version is **required** for: removing or renaming a field, narrowing a type, adding a
required request field, changing the status code for an existing condition, or changing the meaning
of an existing problem `type` URI.

A new major version is **not required** for: adding an optional response field, adding an endpoint,
adding a new problem `type` URI, or changing an opaque cursor's encoding
(`adr/api-collection-contract.md`). Clients must tolerate unknown response fields; a client that
breaks on an added field is not owed a version bump.

### 2. Idempotency: `Idempotency-Key`, as a de facto convention only

Adopted for any `POST` that mints, rotates, or consumes a credential, or that otherwise cannot be
safely retried.

**Status, stated plainly: `draft-ietf-httpapi-idempotency-key-header` is expired and archived.** Its
last revision was v07 (2025-10-15); the Datatracker marks it "Expired & archived — no longer active",
with intended RFC status "(None)". There is no active IETF work and no expectation of publication.
The header is adopted purely because Stripe's implementation made it the de facto convention, and a
widely recognized header name is better than inventing a private one.

Server behavior: store the first response keyed by `(key, route, authenticated subject)` and replay
it for a repeat within the retention window. A repeat of the same key with a different request body
is `422`.

### 3. Rate-limit quota headers: `RateLimit` and `RateLimit-Policy`, defensively

The invented `X-RateLimit-Layer` and `X-RateLimit-Rule` fields are removed. They are not merely
non-standard: naming the rule that fired tells a caller how to reshape traffic to evade it, which
contradicts `docs/security/observability-boundary.md`. Which rule fired belongs in logs and metrics.

The replacement field names are `RateLimit` and `RateLimit-Policy`, from
`draft-ietf-httpapi-ratelimit-headers`.

**Status: not published.** The draft is active at v11 (2026-05-23, expiring 2026-11-24), but an early
HTTPDIR review of v10 returned "Not ready". Field syntax may still change.

Therefore the field names are adopted, but **no client behavior may depend on them**. `Retry-After`
(RFC 9110 §10.2.3, Internet Standard) remains the sole authoritative retry signal, and any client
must behave correctly with the quota headers absent. This constraint is the reason the draft is
adopted at all rather than deferred: the cost of being wrong is bounded to a header name.

### 4. API description: OpenAPI 3.2.x

OpenAPI is maintained by the OpenAPI Initiative under the Linux Foundation. It is not an IETF
standard and never has been; it is the de facto interface description format.

`public/openapi.yml` must describe the endpoints that actually exist. A description naming a route
the router does not serve is worse than no description: it is a published contract the application
does not honor.

Requirements: target 3.2.x; declare the RFC 9457 Problem Details schema once and reference it from
every error response rather than restating error shapes per operation; list real per-surface hosts in
`servers`. Because the file is served from `public/`, it must contain no internal host names, internal
route names, or operational detail that is not already public.

## Scope

Versioning policy; the idempotency mechanism; rate-limit quota header field names; the API
description format and the accuracy requirement on `public/openapi.yml`.

## Non-scope

- Error representation — `adr/api-error-format-problem-details.md`.
- Collection envelope and pagination — `adr/api-collection-contract.md`.
- Route namespace migration from `/edge/v0` and `/web/v0` — `adr/api-route-vocabulary-consolidation.md`,
  which requires its own compatibility review.
- Promoting `v0` to `v1`.
- `Deprecation` and `Sunset` semantics, which are specification-backed (RFC 9745, RFC 8594) and
  therefore recorded in `docs/reference/api-design-standards.md`.

## Consequences

- The versioning policy makes "is this change breaking?" answerable by rule rather than by argument.
- Adopting two non-standard conventions (`Idempotency-Key`, `RateLimit`) means accepting future
  churn. The exposure is bounded: `Idempotency-Key` is frozen in practice because its draft is dead,
  and `RateLimit` is constrained to a header name that no client logic may depend on.
- Removing `X-RateLimit-Rule` is a visible response change for anything that reads it. Nothing in
  this repository does; an external consumer that does was relying on internal enforcement detail it
  should not have received.
- Correcting `public/openapi.yml` will make it larger and will require keeping it current. An
  inaccurate description is the state being corrected, so drift is the failure mode to guard against;
  the accuracy requirement is the guard.
