# Redirect Safety Redesign

## Purpose

Replace scattered redirect allowlist and `allow_other_host: true` usage with one reviewed redirect
boundary for application, sign, apex, and jump surfaces.

## Problem

Current redirect behavior is split across controller concerns and endpoint controllers:

- `Common::Redirect` handles internal safe paths.
- Authentication and OIDC flows issue signed or encoded return targets.
- Jump redirects use `JUMP_ALLOWED_HOSTS` and then call `redirect_to(..., allow_other_host: true)`.
- Several SSO/OIDC controllers allow cross-host redirects after constructing provider URLs.

This makes it hard to audit which redirects are same-host, same-surface, provider-owned, or
externally allowlisted.

## Proposed Direction

1. Introduce a single redirect boundary service, for example `RedirectSafety::Target`, that returns
   a typed result:
   - internal path
   - same-surface URL
   - configured provider URL
   - jump allowlisted external URL
   - rejected target with reason
2. Route every `allow_other_host: true` call through that service or through a small wrapper that
   accepts only a typed approved target.
3. Replace raw ENV parsing in jump redirectors with a normalized host registry that supports default
   ports, explicit non-default ports, and exact host matching only.
4. Keep signed return-target tokens for authentication and step-up continuation. Do not replace
   signed internal continuation with ad-hoc params.
5. Add invariant tests that fail on new `allow_other_host: true` unless the call site is allowlisted
   as a provider handoff or uses the new redirect boundary.

## Security Requirements

- Reject scheme-relative URLs, non-HTTP(S) URLs, userinfo URLs, malformed URLs, and unconfigured
  hosts.
- Treat host and host:port as exact-match values after normalization.
- Never infer cross-surface safety from controller namespace alone.
- Do not log full redirect URLs when they may contain tokens or user-controlled query strings.
- Failure must be fail-closed: render not found, forbidden, or redirect to a fixed local fallback.

## Initial Test Matrix

- Internal relative path is accepted.
- Absolute same-host URL is normalized or rejected according to the chosen API.
- External unlisted host is rejected.
- Listed host with default port is accepted.
- Listed host with explicit non-default port is accepted only when the port is configured.
- Subdomain of a listed host is rejected unless explicitly configured.
- `javascript:`, `data:`, `//host/path`, malformed URLs, and userinfo URLs are rejected.
- Signed return target with wrong purpose, expired token, or wrong surface is rejected.

## Out Of Scope

- Replacing OIDC provider URL construction.
- Changing product redirect destinations.
- Removing existing signed return-target token behavior.
