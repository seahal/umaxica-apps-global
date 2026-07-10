# Public and Private URL Boundaries

## Status

Accepted (2026-06-28)

## Context

This repository needs a single vocabulary for URL ownership across browser-facing screens, edge
hosts, internal Rails origins, and pod-to-pod or pod-to-service callbacks.

Older naming in the codebase mixes several ideas:

- `PUBLIC_*` in a few request-context and helper names
- `EDGE_*` for browser-facing edge hosts
- `*_SERVICE_URL`, `*_STAFF_URL`, and related surface URLs for Rails routes
- `OUTER_*` in deployment/env examples for user-facing endpoints

That mix makes it too easy to confuse the URL a browser should see with the URL Rails or a pod
should use internally.

## Decision

Use two boundary prefixes for URL environment variables and related documentation:

- `PUBLIC_` means a browser-visible or externally reachable URL.
- `PRIVATE_` means a Rails-internal, pod-internal, or service-internal URL.

The public boundary includes canonical user-facing hosts, public edge hosts, externally visible
redirect targets, and browser asset hosts. The private boundary includes internal Rails origins,
cluster-internal callback targets, and pod-local service endpoints.

Prefer `PUBLIC_` and `PRIVATE_` in new documentation, configuration, and code that needs to make the
boundary explicit. Keep actor names, table names, and route names separate from this URL vocabulary.

The existing surface/service host variables remain valid compatibility inputs for now, but they are
no longer the preferred wording in documentation. When a call site needs a user-visible host, it
should read the public boundary name first. When it needs an internal origin, it should read the
private boundary name first.

## Consequences

- Public-vs-private URL ownership becomes readable in config and docs without relying on the old
  outer/inner wording.
- Existing host and audience machinery can migrate incrementally, because compatibility aliases may
  remain until each consumer is updated.
- The old `OUTER_*` wording should be treated as historical. Do not introduce new `OUTER_*` names in
  repository docs or runtime config.

## Related

- `docs/reference/subdomains.md`
- `docs/security/cookie-domain-scope.md`
- `docs/architecture/preference.md`
