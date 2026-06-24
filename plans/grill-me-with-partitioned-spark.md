# CSP Violation Report CSRF Exception — Plan

## Context

Browser-generated CSP violation reports are POST requests that carry no Rails CSRF token and may
arrive with `Origin: null`. All 26 CSP report controllers inherit from their surface-local
`BareController`, which declares:

```ruby
protect_from_forgery using: :header_or_legacy_token, with: :exception
```

Because no CSRF token is present, Rails raises `ActionController::InvalidCrossOriginRequest` and
returns 422 before the request reaches `record_csp_violation!`. The fix is a narrowly action-scoped
`skip_forgery_protection only: :create` applied exclusively to CSP report controllers.

The concern (`CspViolationReport`) and intake service (`CspViolationReportIntake`) already implement
all shared parsing, sanitization, size-limiting, rate-limiting, and event emission. Controllers are
already thin. The refactor is therefore minimal: one change to the concern covers all 26
controllers, plus test hardening and a small docs note.

---

## Investigation Summary

| Area           | Observation                                                                                                                                                                                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Controllers    | 26 files across 8 namespaces × TLDs. All identical: inherit `BareController`, include `CspViolationReport`, call `protect_csp_violation_report_intake`, rescue `ParseError`, `create` calls `record_csp_violation!` then `head :no_content`.                             |
| BareController | Every surface-local `BareController < ActionController::Base` has `protect_from_forgery using: :header_or_legacy_token, with: :exception`. None has `skip_forgery_protection`.                                                                                           |
| Shared concern | `app/controllers/concerns/csp_violation_report.rb` — already owns rate-limit setup, size check, bounded read, and intake call. The class method `protect_csp_violation_report_intake` is the natural insertion point for the CSRF skip.                                  |
| Routes         | All surfaces: `resource :csp_violation_report, only: :create, path: "csp-violation-report"`. Already create-only. No action to take.                                                                                                                                     |
| Existing tests | `test/controllers/csp_violation_reports_controller_test.rb` has 26-surface smoke tests and a test named "post without csrf token returns no content" — but it does not enable forgery protection in the test environment, so it does not prove the production fix works. |
| Intake service | `app/services/csp_violation_report_intake.rb` — defensive: allowlisted fields, bounded strings, URL scrubbing, size guard, JSON parse rescue. No changes needed.                                                                                                         |
| Docs/ADRs      | `adr/csp-violation-report-route-naming.md`, `adr/csp-and-permissions-policy.md`, `docs/security/security-headers.md` — no mention of CSRF handling for CSP endpoints. A one-paragraph note in `docs/security/security-headers.md` will close this gap.                   |

---

## Implementation

### 1. Shared Concern — add `skip_forgery_protection` inside `protect_csp_violation_report_intake`

**File:** `app/controllers/concerns/csp_violation_report.rb`

Add the security-commented skip inside the existing `protect_csp_violation_report_intake` class
method. This single change covers all 26 controllers because every controller already calls this
method.

```ruby
class_methods do
  def protect_csp_violation_report_intake
    # Security exception:
    # CSP violation reports are browser-generated telemetry POSTs and do not include
    # Rails CSRF tokens. They may arrive with Origin: null. This create-only exception
    # records bounded, untrusted telemetry and must not mutate user/account/session state.
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

No controller files change — all 26 already call `protect_csp_violation_report_intake`.

### 2. Tests — add forgery-protection-enabled assertions

**File:** `test/controllers/csp_violation_reports_controller_test.rb`

Replace or augment the existing "post without csrf token returns no content" test with one that
explicitly enables `allow_forgery_protection`, proving the production code path works:

```ruby
test "accepts CSP report without CSRF token even when forgery protection is enabled" do
  host! ENV.fetch("SIGN_SERVICE_URL")

  original = ActionController::Base.allow_forgery_protection
  ActionController::Base.allow_forgery_protection = true

  post sign_app_csp_violation_report_path,
    params: csp_report_payload.to_json,
    headers: { "CONTENT_TYPE" => "application/csp-report" }

  assert_response :no_content
ensure
  ActionController::Base.allow_forgery_protection = original
end

test "accepts CSP report with Origin null header" do
  host! ENV.fetch("SIGN_SERVICE_URL")

  original = ActionController::Base.allow_forgery_protection
  ActionController::Base.allow_forgery_protection = true

  post sign_app_csp_violation_report_path,
    params: csp_report_payload.to_json,
    headers: {
      "CONTENT_TYPE" => "application/csp-report",
      "HTTP_ORIGIN"  => "null",
    }

  assert_response :no_content
ensure
  ActionController::Base.allow_forgery_protection = original
end
```

Keep all existing tests intact. The existing 26-surface smoke test loop implicitly covers
`skip_forgery_protection` side-effects once forgery protection is enabled in the two new tests.

### 3. Docs — one paragraph in `docs/security/security-headers.md`

Add a brief note under the CSP section (or a new "CSP report endpoint" subsection) documenting:

- CSP report endpoints (`POST /csp-violation-report`) intentionally skip CSRF verification on
  `create`.
- Exception is limited to browser-generated telemetry POSTs; no other routes are affected.
- Reports are unauthenticated and untrusted; the endpoint must not mutate session/user/account
  state.
- Brakeman may flag this pattern; the warning is a known accepted false positive given the
  constraints.

---

## Grill-Me Checklist Responses

| Question                                   | Answer                                                                                                           |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| Skip applied to parent/global controller?  | No — placed inside `protect_csp_violation_report_intake` which only runs on controllers that explicitly call it. |
| Accidentally skips a normal HTML route?    | No — `only: :create` is action-scoped; no other controllers call `protect_csp_violation_report_intake`.          |
| All 26 controllers covered?                | Yes — all already call `protect_csp_violation_report_intake`.                                                    |
| Session/actor/account mutation?            | No — `record_csp_violation!` calls only `CspViolationReportIntake.call(...)` then `head :no_content`.            |
| Cookies set?                               | No.                                                                                                              |
| Transparent refresh?                       | No.                                                                                                              |
| Redirects?                                 | No.                                                                                                              |
| Exposes parser internals?                  | No — malformed JSON returns `head :no_content` via `ignore_malformed_csp_report`.                                |
| Accepts huge bodies?                       | No — `csp_report_body_too_large?` guards on `MAX_BODY_BYTES = 64.kilobytes`.                                     |
| Trusts CSP fields as evidence?             | No — all fields are allowlisted and sanitized.                                                                   |
| Routes changed?                            | No — all already `only: :create`.                                                                                |
| Brakeman config touched?                   | No.                                                                                                              |
| Brakeman warning expected?                 | Yes — `SkipBeforeFilter` / `ForgeryCsrfTokens` warning likely; report it, do not suppress it.                    |
| Tests prove original 422 regression fixed? | Yes — new tests with `allow_forgery_protection = true` confirm the fix.                                          |

---

## Files Changed

| File                                                        | Change                                                                                                  |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `app/controllers/concerns/csp_violation_report.rb`          | Add `skip_forgery_protection only: :create` + security comment in `protect_csp_violation_report_intake` |
| `test/controllers/csp_violation_reports_controller_test.rb` | Add 2 forgery-protection-enabled tests                                                                  |
| `docs/security/security-headers.md`                         | Add CSP report endpoint CSRF exception note                                                             |

No controller files change. No routes change. No BareController changes. No Brakeman config changes.

---

## Verification

```sh
# Narrowest: CSP controller tests
bin/rails test test/controllers/csp_violation_reports_controller_test.rb

# Broader: all controller tests
bin/rails test test/controllers

# Brakeman (observe, do not suppress)
bundle exec brakeman
```

Expected Brakeman output: a `ForgeryCsrfTokens` / `SkipBeforeFilter` warning pointing at
`app/controllers/concerns/csp_violation_report.rb`. This is an accepted false positive given the
action-scoped exception and the untrusted-telemetry constraint. Report it; do not add suppressions
or modify `config/brakeman.ignore`.
