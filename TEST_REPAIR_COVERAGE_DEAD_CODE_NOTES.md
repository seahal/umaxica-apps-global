# Test Repair and Coverage Notes

- Timestamp: 2026-06-15T20:00:00Z
  - Target: fixture-loading errors and stale route/model assertions
  - Command run: `COVERAGE=true bin/rails test test/`
  - Finding: the explicit coverage baseline finished at 91.19% line coverage with 6 failures and 4
    errors.
  - Evidence: `Authentication::AuditWriterTest`, `Acme::Org::Oidc::LogoutsControllerTest`,
    `ActorSupportOverlayLanguageTest`, and `ComPreferenceCurrencyOptionTest` failed while loading
    the full shared fixture set; `SignRouteContractTest` and `ModelTableFixtureConsistencyTest`
    reported expectation drift.
  - Decision: repair these in `test/**` only and keep production code untouched for this cluster.

- Timestamp: 2026-06-15T20:00:00Z
  - Target: dead-code candidates
  - Command run: coverage scan from `coverage/.resultset.json`
  - Finding: no deletion candidate is proven dead yet; the current low-coverage hotspots are active
    controllers and concerns with existing test callers.
  - Evidence: the uncovered files are still routed and referenced from active controller and
    coverage tests.
  - Decision: defer deletion until a live-reference audit proves a candidate is unreachable across
    `app/**` and `test/**`.

- Timestamp: 2026-06-15T21:25:00Z
  - Target: dead-code cleanup in `app/controllers/concerns/read_only_content_rendering.rb`,
    `app/controllers/concerns/sign_oidc_connections_management.rb`, and
    `app/models/concerns/version.rb`
  - Command run:
    `rg -n "SignOidcConnectionsManagement|Version|render_content_index|render_content_show" app test`
  - Finding: `SignOidcConnectionsManagement` and `Version` had no direct references in `app/**` or
    `test/**`; `render_content_index` and `render_content_show` were unused HTML helpers in
    `ReadOnlyContentRendering`, while current controllers only call the API rendering methods.
  - Evidence: only `AcmeSettingsOidcConnectionsManagement` is included by active controllers;
    `ReadOnlySurfacesTest` and the docs/help/news controllers exercise `render_content_api_index`
    and `render_content_api_show` instead of the removed HTML helpers.
  - Decision: remove the unreachable concern files and dead HTML helper methods, and keep the live
    API rendering paths intact.

- Timestamp: 2026-06-15T21:25:00Z
  - Target: coverage repair for sequence-gate and read-only content paths
  - Command run:
    `bin/rails test test/controllers/concerns/authentication/sequence_gate_extra_coverage_test.rb test/integration/read_only_surfaces_test.rb test/models/read_only_content_entry_test.rb`
  - Finding: the new sequence-gate coverage and read-only content serialization tests passed after
    adjusting one overly internal assertion.
  - Evidence: 22 runs, 141 assertions, 0 failures, 0 errors, 0 skips.
  - Decision: keep the new tests and use them as the next coverage batch before rerunning the full
    suite.

- Timestamp: 2026-06-15T21:26:00Z
  - Target: settings connection safety check after dead-code cleanup
  - Command run: `bin/rails test test/controllers/acme/authenticator_lifecycle_authority_test.rb`
  - Finding: the controller paths that exercise Acme settings connections and social link/unlink
    behavior stayed green after removing the unused concern file.
  - Evidence: 19 runs, 82 assertions, 0 failures, 0 errors, 0 skips.
  - Decision: treat the removed concern as unreachable dead code and leave the live Acme settings
    concern untouched.

- Timestamp: 2026-06-15T21:48:00Z
  - Target: second coverage batch for token checks and refreshes
  - Command run:
    `bin/rails test test/controllers/acme/edge_v0_token_checks_test.rb test/controllers/acme/edge_v0_token_refreshes_test.rb test/services/jwt_anomaly_subscriber_coverage_test.rb test/controllers/sign/com/edge/v0/token/checks_controller_test.rb`
  - Finding: the new refresh failure-path test, acme token-refresh batch, com token-check success
    path, and subscriber guard/path tests were green after removing the uncertain acme authenticated
    check case.
  - Evidence: 11 runs, 44 assertions, 0 failures, 0 errors, 0 skips.
  - Decision: keep the deterministic token refresh/check and subscriber coverage, and skip the acme
    authenticated check path until the host/resource contract is verified from the codebase rather
    than guessed.

- Timestamp: 2026-06-15T21:55:00Z
  - Target: locale-sensitive read-only surfaces test branch
  - Command run: `COVERAGE=true bin/rails test test/`
  - Finding: a transient full-suite failure appeared in `HandleTest` with a locale-dependent error
    string while the added `I18n.with_locale(:en)` branch was present.
  - Evidence: the isolated `test/models/handle_test.rb` run still passed, and removing the
    locale-swap branch restored the targeted `ReadOnlySurfacesTest` and `HandleTest` pair to green.
  - Decision: drop the locale-swap branch from the coverage test instead of keeping a suite-order
    sensitive setup.

- Timestamp: 2026-06-15T21:59:00Z
  - Target: full-suite coverage rerun after the second batch
  - Command run: `COVERAGE=true bin/rails test test/`
  - Finding: the rerun became contaminated by overlapping coverage jobs and surfaced a fixture load
    deadlock/foreign-key error in `Sign::App::Settings::TotpsControllerTest`.
  - Evidence: the error stack showed PostgreSQL deadlock and foreign-key violations during fixture
    insertion while two coverage runs were in flight.
  - Decision: stop treating this run as a valid coverage measurement and wait for a clean single
    full-suite pass before drawing any conclusions.

- Timestamp: 2026-06-16T12:10:00Z
  - Target: batch start - safe low-coverage targets (validators, jobs, mailers, helpers)
  - Command run: `COVERAGE=true bin/rails test test/` (baseline measurement)
  - Finding: overall app/ coverage is 50.01% line coverage (21218/42429 lines). This is lower than
    the prior 91.33% reported baseline - possible difference in how coverage is being counted across
    suites or in how db migrations are included in the aggregate.
  - Evidence: 2092 app/ files detected, 779 at 100% coverage, 182 services with <50% coverage, 27
    models with <50% coverage, 183 controllers with <50% coverage.
  - Decision: focus on safe, small targets with clear test patterns - validators (32 uncovered),
    jobs (44 uncovered), mailers (67 uncovered), helpers (115 uncovered) - total batch target is 88
    uncovered lines across 15 files. After this batch, rerun full coverage and assess progress
    toward 95% line coverage target.

- Timestamp: 2026-06-16T12:25:00Z
  - Target: investigation - coverage baseline audit
  - Command run: analysis of `.resultset.json` and git status check
  - Finding: the 50.01% app/ coverage appears to be accurate; test suite has uncommitted changes (db
    structures modified, test files modified); coverage measurement appears to stop early with
    "Stopped processing SimpleCov as a previous error not related to SimpleCov has been detected"
  - Evidence: 15 error files (14 < 100%), 368 policy files (47 < 100%, 332 uncovered), validators
    already covered by model tests, jobs already have comprehensive tests; modified db structure
    files suggest schema changes in progress
  - Decision: defer aggressive coverage push until test suite stabilization; focus on smallest,
    safest targets to verify tooling works: error classes (29 total uncovered lines, non-security),
    utility value objects (18 uncovered), forms (1 uncovered). Start with 1-line error file tests to
    confirm test patterns work, then assess whether full coverage push is feasible given baseline.

- Timestamp: 2026-06-16T12:35:00Z
  - Target: kill-switch trigger - test suite infrastructure blocker
  - Command run: `bin/rails test test/forms/application_form_test.rb` and
    `bin/rails test test/unit/jit/utils/email_validator_test.rb`
  - Finding: test runner cannot start - pending migrations block all test execution. The suite has
    1842 pending migrations that block fixture loading and test initialization.
  - Evidence: both test runs fail at "Migrations are pending. To resolve this issue, run: bin/rails
    db:migrate". Permitted commands do not include `bin/rails db:migrate`. The COVERAGE run also
    stops early with "Stopped processing SimpleCov as a previous error not related to SimpleCov has
    been detected".
  - Decision: KILL SWITCH - coverage work is blocked by test infrastructure failure. The test suite
    cannot run to completion due to pending migrations. Adding test coverage is impossible until the
    migrations are applied and the test suite can start. This is a database/schema setup issue
    outside the scope of test coverage repair. Recommended next steps: (1) investigate pending
    migrations and schema drift, (2) apply or rebuild database schema, (3) verify test suite runs to
    completion, (4) then resume coverage work with a clean baseline.
