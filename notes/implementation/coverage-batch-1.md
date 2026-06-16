# Coverage Improvement — Batch 1

## Goal
Raise Rails test line coverage from 90.69% to 95% across the application.

## Result
Batch 1 added **5 new covered lines** (40490 → 40495), raising coverage from 90.689% to 90.698%.

## Changes Made

### Tests Added/Modified
1. `test/unit/actor/preference_test.rb` — `test_hash_returns_all_preferences_as_hash`
2. `test/models/actor/authentication_test.rb` — `test_hash_returns_all_fields_as_hash`
3. `test/models/chronicle_test.rb` — fixed metadata oversize test to use `(0..5000).to_h { |i| [i.to_s, i] }` instead of large strings (sanitized by `ChronicleRecorder.sanitize`)
4. `test/models/operator_chronicle_event_test.rb` — `test_hash_method` and `test_ensure_defaults_method`
5. `test/models/actor_test.rb` — `test_step_up_null`
6. `test/validators/recovery_identity_required_validator_test.rb` — new file testing symbol message path and nil owner
7. `test/mailers/concerns/safe_promotional_cta_url_test.rb` — new file testing URI parse error rescue
8. `test/mailers/concerns/promotional_email_unsubscribe_headers_test.rb` — new file testing unsubscribe header methods
9. `test/services/step_up_requirement_test.rb` — new file testing `build` with Hash and nil values
10. `test/services/oidc_authorization_transaction_service_test.rb` — added `model_for` unsupported surface test
11. `test/services/sign_up/contracts_test.rb` — added unsupported ticket class test
12. `test/services/dpop_proof_state_store_test.rb` — new file testing `for` class method (covers else branch)
13. `test/services/core_host_normalization_test.rb` — new file testing invalid URI rescue path
14. `test/services/sign_in/guardrail_participant_test.rb` — added evaluator returning non-item test

### Files Corrected
- `test/helpers/sign/org/sign_ups_helper_test.rb` — replaced invalid UTF-8 byte with valid URI
- `test/models/actor_test.rb` — used `.with(...)` syntax for `Data.define` partial construction

## Key Insights
- `ChronicleRecorder.sanitize` recursively truncates all string values > 65 bytes to `"[FILTERED]"`, so large metadata values get filtered before JSON size validation. Use many small non-string values (integers) to bypass sanitization and trigger the oversize error.
- `Actor::StepUp` is `Data.define(...)` — all fields keyword-required; use `.with(field: val)` instead of `.new(...)`.
- `CoreHostNormalization.normalize("\x00")` triggers the `URI::InvalidURIError` rescue path.

## Remaining Strategy
- Target files with 1–3 uncovered lines in models, services, validators, and helpers.
- Avoid auth/session/OIDC/token flows (security-sensitive).
- Avoid controllers, jobs (often require multi-db setup or ceremony tables), and concerns with complex relationships.
- Some services with 1 uncovered line (e.g., `identity_one_time_reveal.rb`, `oidc_client_assertion_jwt.rb`, `jump_rt_issuer.rb`, `sign_in_otp_resend_state.rb`) have simple `rescue nil` patterns that can be tested with invalid input.
- Controller-level uncovered lines (~80+ files with 1 line each) are likely reachable only through integration tests with specific edge cases.
