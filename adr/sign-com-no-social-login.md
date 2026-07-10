# Sign :com Excludes Social Login

**Status:** Accepted (2026-05-05); temporary Google exception withdrawn on 2026-06-02

## Context

The IdP runs three host scopes: `app` (`id.umaxica.app`, service users), `com` (`id.umaxica.com`,
corporate visitors), and `org` (`id.umaxica.org`, staff). Social login is a product capability of
the `app` surface only. The corporate `com` flow uses local account methods and must not expose
Google, Apple, Microsoft, or other external social providers.

Historically, view fallback and process-wide OmniAuth middleware could make app social controls or
direct `/auth/...` requests reachable from the corporate host. That is not a valid corporate surface
boundary.

## Decision

`com` does not offer or accept social login.

- `com` sign-up and sign-in views omit social provider UI.
- Direct `/auth/...` requests on the corporate host are rejected before OmniAuth can start a social
  flow.
- The corporate Google provider is not registered as an OmniAuth strategy.
- The prior QA-only corporate Google temporary gateway is withdrawn and removed before production.

`app` keeps its Google and Apple social login behavior. `org` is now also no-social, but this ADR is
specifically the corporate no-social boundary.

## Consequences

- `POST /auth/google_app`, `POST /auth/apple`, and any unregistered social provider path return not
  found on the corporate host.
- No corporate Google social environment flags are valid.
- Future social-bearing app views must not leak to `com` through fallback rendering.
- Reintroducing any social provider to `com` requires a new accepted ADR.
