# Remove Brittle WebAuthn Fallback Without Relying-Party

Status: Closed — implemented in working tree (verified 2026-05-05). Severity: was Medium
(defense-in-depth).

## Summary

This plan is closed. The required changes are present in the current working tree of the `develop`
branch:

- `app/controllers/concerns/sign/webauthn.rb:40-45` defines a per-request `webauthn_relying_party`
  returning `WebAuthn::RelyingParty.new(...)`.
- `app/controllers/concerns/sign/webauthn.rb:39` carries the design comment "This avoids mutating
  global WebAuthn.configuration state."
- `with_webauthn_config` (the previous global-mutation pattern) no longer exists in the codebase.
- All 9 `WebAuthn::Credential.from_get` / `from_create` call sites in `app/` pass
  `relying_party: webauthn_relying_party` explicitly. There is no fallback branch.

No further action is needed. This file is retained for traceability.
