# Defense-in-Depth Host Allowlist for Jump Redirector

Status: Closed — implemented in working tree (verified 2026-05-05). Severity: was Low/Medium
(defense-in-depth).

## Summary

This plan is closed. `app/controllers/concerns/jump/to_redirector.rb` already implements the
required defense:

- L.23-27: `validate_destination_url!` is called before redirect; on failure the controller emits a
  `redirect.blocked` event and returns 404.
- L.43-53: scheme allowlist — only `http` and `https` accepted.
- L.62-71: host allowlist via `ENV["JUMP_ALLOWED_HOSTS"]` (comma-separated, case-insensitive).

## Remaining nit (out of scope here)

Model-level write-time validation is still presence-only on `destination_url`
(`app/models/concerns/jump_linkable.rb:21-25`). Adding a URL-format validation at the model layer
would close the controller-only defense gap, but is not urgent — current write paths are
operator/admin only. Track separately if and when needed.
