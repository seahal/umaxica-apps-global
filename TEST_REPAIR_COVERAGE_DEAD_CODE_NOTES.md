# Test Repair and Coverage Notes

- Timestamp: 2026-06-15T20:00:00Z
  - Target: fixture-loading errors and stale route/model assertions
  - Command run: `COVERAGE=true bin/rails test test/`
  - Finding: the explicit coverage baseline finished at 91.19% line coverage with 6 failures and 4 errors.
  - Evidence: `Authentication::AuditWriterTest`, `Acme::Org::Oidc::LogoutsControllerTest`, `ActorSupportOverlayLanguageTest`, and `ComPreferenceCurrencyOptionTest` failed while loading the full shared fixture set; `SignRouteContractTest` and `ModelTableFixtureConsistencyTest` reported expectation drift.
  - Decision: repair these in `test/**` only and keep production code untouched for this cluster.

- Timestamp: 2026-06-15T20:00:00Z
  - Target: dead-code candidates
  - Command run: coverage scan from `coverage/.resultset.json`
  - Finding: no deletion candidate is proven dead yet; the current low-coverage hotspots are active controllers and concerns with existing test callers.
  - Evidence: the uncovered files are still routed and referenced from active controller and coverage tests.
  - Decision: defer deletion until a live-reference audit proves a candidate is unreachable across `app/**` and `test/**`.

- Timestamp: 2026-06-15T21:25:00Z
  - Target: dead-code cleanup in `app/controllers/concerns/read_only_content_rendering.rb`, `app/controllers/concerns/sign_oidc_connections_management.rb`, and `app/models/concerns/version.rb`
  - Command run: `rg -n "SignOidcConnectionsManagement|Version|render_content_index|render_content_show" app test`
  - Finding: `SignOidcConnectionsManagement` and `Version` had no direct references in `app/**` or `test/**`; `render_content_index` and `render_content_show` were unused HTML helpers in `ReadOnlyContentRendering`, while current controllers only call the API rendering methods.
  - Evidence: only `AcmeSettingsOidcConnectionsManagement` is included by active controllers; `ReadOnlySurfacesTest` and the docs/help/news controllers exercise `render_content_api_index` and `render_content_api_show` instead of the removed HTML helpers.
  - Decision: remove the unreachable concern files and dead HTML helper methods, and keep the live API rendering paths intact.

- Timestamp: 2026-06-15T21:25:00Z
  - Target: coverage repair for sequence-gate and read-only content paths
  - Command run: `bin/rails test test/controllers/concerns/authentication/sequence_gate_extra_coverage_test.rb test/integration/read_only_surfaces_test.rb test/models/read_only_content_entry_test.rb`
  - Finding: the new sequence-gate coverage and read-only content serialization tests passed after adjusting one overly internal assertion.
  - Evidence: 22 runs, 141 assertions, 0 failures, 0 errors, 0 skips.
  - Decision: keep the new tests and use them as the next coverage batch before rerunning the full suite.

- Timestamp: 2026-06-15T21:26:00Z
  - Target: settings connection safety check after dead-code cleanup
  - Command run: `bin/rails test test/controllers/acme/authenticator_lifecycle_authority_test.rb`
  - Finding: the controller paths that exercise Acme settings connections and social link/unlink behavior stayed green after removing the unused concern file.
  - Evidence: 19 runs, 82 assertions, 0 failures, 0 errors, 0 skips.
  - Decision: treat the removed concern as unreachable dead code and leave the live Acme settings concern untouched.
