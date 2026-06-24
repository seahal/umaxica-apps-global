# Plan: CSP Violation Report CSRF Exception

## Context

Browser-generated CSP violation reports are POST requests that carry no Rails CSRF token and may
arrive with `Origin: null`. All CSP report controllers inherit from their surface-local
`BareController`, which explicitly enables:

```ruby
protect_from_forgery using: :header_or_legacy_token, with: :exception
```

Rails therefore rejects CSP report POSTs with 422 / `ActionController::InvalidCrossOriginRequest`
before `record_csp_violation!` executes. The existing test "post without csrf token returns no
content" passes only because forgery protection is globally disabled in the test environment by
default — it does not prove the production path is safe.

## Investigation Summary

**Affected controllers:** 27 CSP violation report controllers spanning modules Sign, Acme, Core,
Base, Help, Palm, News, Docs across app/com/org/net/dev surfaces. All follow this exact pattern:

```ruby
class CspViolationReportsController < BareController
  include CspViolationReport
  AUTHENTICATION_MODE = :bare
  protect_csp_violation_report_intake
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :ignore_malformed_csp_report

  def create
    record_csp_violation!
    head :no_content
  end
end
```

**All routes are create-only:**

```ruby
resource :csp_violation_report, only: :create, path: "csp-violation-report"
```

Confirmed in config/routes/core.rb, acme.rb, palm.rb, help.rb, base.rb, news.rb, docs.rb.

**Parsing/sanitization centralized in:** `app/services/csp_violation_report_intake.rb`

**Existing `with_forgery_protection` helper** already present at
`test/support/missing_helpers.rb:264-270` — no need to add it.

## Files to Change

### 1. `app/controllers/concerns/csp_violation_report.rb`

Add `skip_forgery_protection only: :create` as the first call inside
`protect_csp_violation_report_intake`, with the required security comment above it:

```ruby
class_methods do
  def protect_csp_violation_report_intake
    # Security exception:
    # CSP violation reports are browser-generated telemetry POSTs and do not
    # include Rails CSRF tokens. They may arrive with Origin: null.
    #
    # This helper must only be called by create-only CSP report controllers.
    # The endpoint records bounded, unauthenticated, untrusted telemetry only
    # and must not authenticate actors, mutate user/account/session state,
    # refresh cookies, or redirect.
    skip_forgery_protection only: :create

    if respond_to?(:rate_limit)
      rate_limit(
        to: 120,
        within: 1.minute,
        only: :create,
        store: Rails.configuration.x.rate_limit.fetch(:store),
      )
    end

    rescue_from(ActionController::TooManyRequests, with: :ignore_rate_limited_csp_report)
  end
end
```

No individual controller files need to be edited because all 27 controllers already call
`protect_csp_violation_report_intake`.

### 2. `test/controllers/csp_violation_reports_controller_test.rb`

Add new tests using the existing `with_forgery_protection` helper:

- **A.** POST without CSRF token succeeds with forgery protection explicitly enabled → 204
- **B.** `Origin: null` with forgery protection enabled → 204 (direct regression case)
- **C.** No Set-Cookie header on accepted response
- **E.** Ordinary CSRF-protected endpoint still rejects tokenless POST when forgery protection is
  enabled (regression guard)

Update existing "post without csrf token returns no content" to use `with_forgery_protection` so it
proves production behavior rather than test-mode behavior.

### 3. `docs/security/security-headers.md`

Add a subsection under CSP documentation:

```markdown
## CSP Violation Report Endpoints

CSP violation report endpoints intentionally skip Rails CSRF verification for the `create` action
only.

- Browser-generated CSP reports do not include Rails authenticity tokens and may arrive with
  `Origin: null`.
- These endpoints are unauthenticated telemetry ingestion points.
- Submitted reports are **untrusted** and must not be treated as authoritative evidence.
- The endpoint must not authenticate actors, mutate user/account/session/cookie state, or redirect.
- Body-size limits, field sanitization, and rate limiting (120 req/min) remain in effect.
- Static analysis tools may flag `skip_forgery_protection` on these endpoints. This is an
  intentional, reviewed security exception under the documented create-only and telemetry-only
  constraints. No Brakeman suppression is applied.
```

## No Individual Controller Edits Required

All 27 CSP report controllers already call `protect_csp_violation_report_intake`. The concern change
propagates automatically.

## Security Constraints Satisfied

- `skip_forgery_protection only: :create` — scoped to create action only
- Added only via `protect_csp_violation_report_intake` — only callable by CSP report controllers
- No BareController modification
- No session/cookie/actor mutation in these controllers
- No redirect

## Verification

```bash
bin/rails test test/controllers/csp_violation_reports_controller_test.rb
bin/rails test test/controllers
bundle exec brakeman
```

Report Brakeman output verbatim; do not suppress any warning.
