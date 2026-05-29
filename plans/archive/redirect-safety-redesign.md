# Redirect Safety Redesign

Status: Completed — implemented in working tree (verified 2026-05-28).

## Completion Notes

This plan is complete for the current Rails-side redirect boundary scope.

- Cross-host dynamic redirects now go through the Jump `rt` gateway boundary instead of direct
  `allow_other_host: true` redirects.
- `allow_other_host: true` is limited to `Common::Redirect`, which issues or validates Jump gateway
  targets.
- External redirect helpers use `redirect_to_external_jump` / `redirect_to_external_jump_url`; the
  legacy `redirect_to_xt` / `redirect_to_xt_url` facade is retired and guarded by an invariant test.
- Rails-issued Jump `rt` tokens include signed destination claims and a replay policy claim.
  `rpl: "reuse"` is the default; `rpl: "once"` enables Rails-side returned-token `jti` replay
  detection for flows that explicitly require one-time use.
- Returned Jump `rt` verification checks Jump JWKS, issuer, audience, source policy, destination
  kind, URL equality after removing `rt`, and optional one-time replay policy.
- Mailer promotional CTA URLs and the org sign-up recruit contact link are not HTTP redirect
  boundaries, but they now reject unsafe URL forms so they cannot emit dangerous schemes or
  credential-bearing URLs.
- Regression coverage now pins the Jump redirect facade, returned-token verification, legacy `xt`
  removal, raw authentication `pt` restrictions, and representative unsafe external-link inputs.

Related source-of-truth update:

- `adr/secure-jump-link-redirector.md` contains the accepted JWS Gateway Return Round Trip and
  Signed Path Targets decisions.

## Purpose

Replace scattered redirect allowlist and `allow_other_host: true` usage with one reviewed redirect
boundary for application, sign, acme, and jump surfaces.

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
