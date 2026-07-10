# Restoration A8: CSP and Permissions-Policy

Extracted from `plans/archive/global-repo-restoration-plan.md` (2026-05-07).

## Source

- `adr/csp-and-permissions-policy.md`

## Goal

Ship the documented Content-Security-Policy and Permissions-Policy headers. Tighten in the order the
ADR prescribes (report-only → enforce).

## Key surface

`config/initializers/content_security_policy.rb` (or equivalent), middleware / layout that emits
Permissions-Policy.

## Verification

Request specs that assert headers on representative routes (HTML page, JSON API, OIDC pages).

## Adaptation notes

Allow-list hosts must include `id.*` and `www.*`, drop `sign.*`. WebAuthn related directives must
reflect the new RP ID.

## Related

- `plans/backlog/gh231-configure-csp.md` — GH-231 CSP configuration ticket.
- `plans/backlog/gh266-permissions-policy.md` — GH-266 Permissions-Policy ticket.
- `plans/backlog/gh645-csp-violation-reporting.md` — CSP violation reporting endpoint.
