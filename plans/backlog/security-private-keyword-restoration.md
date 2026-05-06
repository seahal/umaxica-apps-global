# Audit Visibility Boundary in `Common::Redirect` after `private` Restoration

Status: Not Started Severity: Low (defense-in-depth) Origin: Security review follow-up; verified
working tree on 2026-05-05 already has `private` restored in both `common/redirect.rb` and
`sign/webauthn.rb`.

## Summary

Earlier on this branch, two concerns had their `private` keyword commented out in commit 2442ac81c.
The keyword has since been restored:

- `app/controllers/concerns/common/redirect.rb:43` — `private`
- `app/controllers/concerns/sign/webauthn.rb:151` — `private`

The `webauthn.rb` boundary matches the original intent (every helper below `private` is what `main`
had as private). No action there beyond a regression test.

The `redirect.rb` boundary changed:

| Method                     | Visibility on `main` | Visibility now |
| -------------------------- | -------------------- | -------------- |
| `safe_internal_path`       | private              | private        |
| `safe_redirect_to`         | private              | **public**     |
| `safe_redirect_back_or_to` | private              | **public**     |
| `generate_redirect_url`    | private              | private        |
| `jump_to_generated_url`    | private              | private        |

`safe_redirect_to` and `safe_redirect_back_or_to` are now public on every including controller. They
are not routable as actions (no `match … :action` or wildcard dispatch in `config/routes/`), so this
is not a live exposure — but it is a wider public API than `main` had, and may have been an
oversight during the `private` restoration.

## Required Work

1. Determine intent. Inspect git history on `redirect.rb` and find which commit re-added `private`
   and where it placed the line. If the placement was deliberate (e.g., callers in views or other
   concerns now rely on these methods being public), document why in the file and add an ADR note.
   If accidental, move the `private` keyword above `safe_redirect_to`.
2. Audit callers of `safe_redirect_to` and `safe_redirect_back_or_to` across `app/`. If every caller
   is itself a controller action body or helper-on-self call, both methods can safely return to
   private.
3. Add a regression test (per concern) asserting the expected private-method set, so the "Ruby 4.0
   compatibility" workaround cannot recur silently. One acceptable shape:
   ```ruby
   test "Common::Redirect private surface" do
     controller = Class.new(ApplicationController) { include Common::Redirect }.new
     assert_not controller.public_methods.include?(:safe_internal_path)
     assert_not controller.public_methods.include?(:generate_redirect_url)
     assert_not controller.public_methods.include?(:jump_to_generated_url)
   end
   ```
   Add an analogous assertion for `Sign::Webauthn`.

## Affected Files

- `app/controllers/concerns/common/redirect.rb` — possibly relocate `private`.
- `test/controllers/concerns/common/redirect_test.rb` — new regression test.
- `test/controllers/concerns/sign/webauthn_test.rb` — new regression test.

## Acceptance Criteria

- The visibility boundary in `redirect.rb` is either reverted to match `main` or explicitly
  documented as an intentional widening.
- A regression test pins the private-method set per concern.
- No `# Removed private` comments remain in the codebase.

## How to Apply

Single PR. Small enough that an audit + tests + boundary fix fit together.
