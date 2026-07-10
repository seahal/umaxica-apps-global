# API Schema And Contract Documentation Plan

## Status

Backlog proposal. Do not implement broad API changes from this file until an ADR or active plan
accepts the contract ownership model.

## Current Finding

`public/openapi.yml` currently documents only the shared health response shape under `/v0/health`.
That is consistent with the existing selective approach in `docs/test.md`: Rails controller and
integration tests own most behavior contracts, while OpenAPI / committee-style schema validation is
adopted only where schemas exist.

The repository does not currently have an accepted ADR that says every Rails endpoint must be
described in OpenAPI. Several ADRs and docs instead treat route contracts, identity ceremony
contracts, and health contracts as separate source-of-truth documents.

## Proposed Policy

- Keep `public/openapi.yml` as the public HTTP schema surface only for endpoints that are intended
  to have stable external JSON contracts.
- Keep security-sensitive ceremony tokens, OIDC/OAuth claims, and identity handoff contracts in
  dedicated ADR/docs plus focused contract tests.
- Keep browser HTML routes out of OpenAPI unless they expose a stable JSON API.
- Require each new public JSON endpoint to choose one contract home before implementation: OpenAPI
  schema, dedicated ADR/doc contract, or route/controller integration contract tests.
- Document the chosen contract home in the plan or ADR for the feature.

## Follow-Up Work

1. Inventory current JSON endpoints by surface and classify them as public external API, browser
   internal endpoint, protocol endpoint, or operational endpoint.
2. Decide whether OIDC discovery, JWKS, token, userinfo, health, and edge compatibility endpoints
   should be represented in OpenAPI or remain in dedicated protocol/route contract tests.
3. Add only the accepted stable JSON contracts to `public/openapi.yml`.
4. Add schema validation tests where OpenAPI is the chosen contract home.
