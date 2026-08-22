# API Schema And Contract Documentation Plan

## Status

**Superseded (2026-08-22) by `plans/rails-nextjs-openapi-contract-audit.md`.** Retained for
traceability. The contract ownership model this file asked for has been decided; see that document
and `adr/api-versioning-and-client-conventions.md` section 4 as amended 2026-08-22.

Its selective-coverage policy below was accepted and carries forward. Its stated finding is stale
and its follow-up list is complete or superseded. Do not plan from this file.

## Current Finding

_Stale as of 2026-08-22. Corrected below; the original text is retained because the policy section
was written against it._

> `public/openapi.yml` currently documents only the shared health response shape under `/v0/health`.
> That is consistent with the existing selective approach in `docs/test.md`: Rails controller and
> integration tests own most behavior contracts, while OpenAPI / committee-style schema validation
> is adopted only where schemas exist.
>
> The repository does not currently have an accepted ADR that says every Rails endpoint must be
> described in OpenAPI. Several ADRs and docs instead treat route contracts, identity ceremony
> contracts, and health contracts as separate source-of-truth documents.

Correction, verified 2026-08-22:

- `public/openapi.yml` is 581 lines at `openapi: 3.2.0` describing nine paths: `/health`,
  `/health/{liveness,readiness,startup}`, `/api/v0/session`, `/api/v0/token/refresh`,
  `/api/v0/profile`, `/api/v0/entries`, and `/api/v0/entries/{slug}`. It is not health-only, and
  `/v0/health` is not among them.
- `adr/api-versioning-and-client-conventions.md` (Accepted 2026-08-16) does make OpenAPI the
  accepted API description format and imposes an accuracy requirement on the file. Its section 4 was
  amended on 2026-08-22 to target 3.0.4 rather than 3.2.x, because `committee` and
  `openapi-typescript` do not support 3.1 or 3.2.
- The unchanged part of the finding is the important part: nothing reads the file. There is no test,
  initializer, rake task, or CI job that references it, so the accuracy requirement has no
  enforcement. That is what the superseding plan addresses.

## Proposed Policy

_Accepted. Carried forward into `plans/rails-nextjs-openapi-contract-audit.md`, whose decisions D3
(initial scope), D12 (no documentation UI), and the protocol exemptions in
`docs/reference/api-design-standards.md:266-282` implement it._

- Keep `public/openapi.yml` as the public HTTP schema surface only for endpoints that are intended
  to have stable external JSON contracts.
- Keep security-sensitive ceremony tokens, OIDC/OAuth claims, and identity handoff contracts in
  dedicated ADR/docs plus focused contract tests.
- Keep browser HTML routes out of OpenAPI unless they expose a stable JSON API.
- Require each new public JSON endpoint to choose one contract home before implementation: OpenAPI
  schema, dedicated ADR/doc contract, or route/controller integration contract tests.
- Document the chosen contract home in the plan or ADR for the feature.

## Follow-Up Work

Status as of 2026-08-22:

1. Inventory current JSON endpoints by surface and classify them as public external API, browser
   internal endpoint, protocol endpoint, or operational endpoint. — **Done.**
   `plans/rails-nextjs-openapi-contract-audit.md` sections 4 and 5.
2. Decide whether OIDC discovery, JWKS, token, userinfo, health, and edge compatibility endpoints
   should be represented in OpenAPI or remain in dedicated protocol/route contract tests. —
   **Done.** `docs/reference/api-design-standards.md:266-282` exempts OAuth 2.0, OIDC including
   UserInfo and back-channel logout, WebAuthn, DBSC, MCP, and `.well-known` from the response-format
   rules; the audit keeps them out of the description. Health is described. `/edge/v0` and `/web/v0`
   are deferred to the audit's Phase F, which converges them on `/api/v0` rather than describing
   them in place.
3. Add only the accepted stable JSON contracts to `public/openapi.yml`. — **Superseded.** The audit
   splits the description per surface into `public/openapi.{app,com,org}.yml`, because a single
   document with a default host cannot express which surface serves which path
   (`.agents/harnesses/rules/project/surfaces.mdc:24-26`).
4. Add schema validation tests where OpenAPI is the chosen contract home. — **Still outstanding, and
   now planned.** Audit Phase B wires `committee-rails` (already in `Gemfile:187`, referenced by
   zero lines of code) into the Minitest suite, with a bidirectional route-coverage test. This is
   the item that made the accuracy requirement unenforceable.
