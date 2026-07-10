# Closed: Audit Visibility Boundary in `Common::Redirect` after `private` Restoration

Status: Closed — implemented in working tree. Severity: was Low (defense-in-depth).

## Summary

The visibility boundary issue was resolved in the working tree:

- `app/controllers/concerns/common/redirect.rb` keeps the redirect helpers private
- `app/controllers/concerns/sign/webauthn.rb` keeps the WebAuthn helper boundary private
- regression tests pin the intended method visibility

## Result

No further action is needed. This note is retained for traceability only.
