# Test Repair and Coverage Notes

## Baseline attempt

- Command: `COVERAGE=true bin/rails test`
- Result: failed before tests loaded.
- Failure: `ActiveRecord::DatabaseConnectionError` / `PG::ConnectionBad`
- Root cause observed in this environment:
  - hostname `primary` did not resolve
  - `localhost:5432` had no PostgreSQL response
  - `docker` and `podman` are not installed in this shell
  - client tools are present, but PostgreSQL server binaries are not on `PATH`

## Status

- Coverage baseline could not be measured because the test database is unavailable.
- No in-repo code changes were made for this step.

## Updated baseline attempt

- `db:prepare` now succeeds after fixing `db/seeds.rb` to use `ClientTotpCredentialStatus`.
- `COVERAGE=true bin/rails test test/` now runs and reaches the full suite.
- Baseline result for the requested command:
  - `7301` runs
  - `28528` assertions
  - `19` failures
  - `19` errors
  - `90.81%` line coverage
- SimpleCov reported the expected minimum as `93.00%`, so this run still falls short.
- Observed failures so far are in the auth / sign-up / credential-removal area and match the plan's
  kill-switch categories:
  - `SocialAuthLoginTest#test_Google_login_with_existing_identity_does_not_create_new_user`
  - `AuthenticationFlowTest#test_guest_can_access_login_page`
  - `Sign::Com::Settings::SecretCredentialsControllerTest#test_create_persists_secret_credential_and_redirects`
  - `Sign::Com::Settings::SecretCredentialsControllerTest#test_index_show_and_edit_redirect_to_acme_while_new_remains_on_sign`
  - `Security::AuthenticationModeInventoryTest#test_controller_files_declare_a_local_authentication_mode`
  - `SocialAuthAppFlowContractTest` sign-up birthdate template failures
  - `Sign::Org::CredentialRemovalConstraintsTest#test_email_telephone_passkey_and_secret_credential_removals_are_allowed_when_dimensions_remain`
  - `Sign::App::Settings::TotpsControllerTest` / `Sign::App::Settings::PasskeysControllerTest`
  - `Sign::Org::Settings::PasskeysControllerTest`
  - `Security::ForbiddenPatternsInvariantTest`
  - `RailsWayHarnessInventoryTest`
  - `PageTitlePresenceTest`
  - `OidcClientRegistryTest`
