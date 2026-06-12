# Coverage Test-Only Notes

## 2026-06-12T12:13:00+00:00 — Skip: complex models requiring DB fixtures

- **Targets**: `Agent`, `Individual`, `Persona`, `Bureau`, `BureauUnit`, `BureauUnitClosure`,
  `Company`, `CompanyUnit`, `CompanyUnitClosure`, `Enterprise`, `EnterpriseUnit`,
  `EnterpriseUnitClosure`, `OperatorLifecycleRequest`, `OperatorWorkspaceAccount`,
  `OperatorWorkspaceAccountMembership`, `MemberNotification`, `Department`, `Division`,
  `Organization`, `ClientProfile`, `OperatorClientOccurrence`
- **Reason**: These models include concerns (`Account`, `Collective`, `CollectiveUnit`,
  `Retainable`, `PublicId`) or have `belongs_to` constraints requiring associated DB records.
  Testing them without fixtures or DB records would require complex setup. The `new(id: ...)`
  pattern would fail due to NOT NULL foreign key constraints or required validations.
- **Command**: None
- **Decision**: **skipped** — left for fixture-backed or integration-level coverage

## 2026-06-12T12:13:00+00:00 — Skip: occurrence join models

- **Targets**: `AreaOperatorOccurrence`, `EmailOperatorOccurrence`, `DomainOperatorOccurrence`,
  `IpOperatorOccurrence`, `OperatorClientOccurrence`
- **Reason**: These inherit from `OccurrenceRecord` (occurrence DB). The occurrence DB is not
  configured in development mode (`development_occurrence_db` does not exist), and while test mode
  works, testing these requires creating associated records (`OperatorOccurrence`,
  `ClientOccurrence`) via DB writes. Safe characterization via `new(id: ...)` fails because
  `belongs_to` NOT NULL constraints prevent validation without associated records.
- **Command**: None
- **Decision**: **skipped** — existing tests for structurally identical join models (e.g.,
  `AreaClientOccurrenceTest`, `OperatorClientOccurrenceTest`) show the expected pattern

## 2026-06-12T12:13:00+00:00 — Skip: preference models

- **Targets**: `AppPreferenceAdultContentGate`, `AppPreferenceCurrency`, `AppPreferenceDensity`,
  `AppPreferenceMotion`, `AppPreferencePageSize`, `AppPreferenceTimeFormat`,
  `ComPreferenceAdultContentGate`, `ComPreferenceCurrency`, etc.
- **Reason**: These have `belongs_to :preference` and `validates :preference_id, uniqueness: true`.
  Testing via `new(...)` requires either mocking a `preference` association or setting
  `preference_id` to an existing DB record. The preference models involve `before_validation`
  callbacks and cross-table dependencies. Not safe for test-only characterization.
- **Command**: None
- **Decision**: **skipped** — left for fixture-backed or integration-level coverage

## 2026-06-12T12:13:00+00:00 — Skip: token / credential / OIDC / auth models

- **Targets**: `ClientSecretCredentialKind`, `ClientSecretCredentialStatus`,
  `OperatorSecretCredentialStatus`, `VisitorSecretCredentialKind`, all `*_oidc_*`, `*_session_*`,
  `*_sign_in_flow_*`, `*_sign_up_flow_*`, `*_sign_out_flow_*`, `*_withdrawal_flow_*`,
  `*_step_up_session_*`, `*_dpop_proof_state_*`, `*_oauth_callback_state_*`,
  `*_email_ceremony_transaction_*`, `*_passkey_ceremony_transaction_*`,
  `*_telephone_ceremony_transaction_*`, `*_totp_ceremony_transaction_*`,
  `*_secret_credential_ceremony_transaction_*`, `*_social_ceremony_transaction_*`,
  `*_step_up_ceremony_transaction_*`
- **Reason**: Security-sensitive ceremony, auth, token, credential, and OIDC models. Per
  constraints, avoid high-coupling auth/session/token/security/OIDC models. Testing these requires
  understanding authentication flows and may introduce risk. Note: `ClientTokenKind`,
  `OperatorTokenKind`, `VisitorTokenKind` are simple device-type enums (ReferenceRecord) and were
  tested in batch 2 as low-risk.
- **Command**: None
- **Decision**: **skipped** — maintained exclusion per scope rules

## 2026-06-12T12:15:00+00:00 — Skip: chronicle model validation tests (I18n)

- **Targets**: `ChronicleRetentionPolicy#duration_days`, `ChronicleRetentionPolicy#permanent`,
  `ChronicleOutboxEntry#event`, `ChronicleOutboxEntry#event_uuid`, `ChronicleOutboxEntry#payload`
- **Reason**: These attributes lack Japanese locale translations. Calling `valid?` on invalid
  records triggers `I18n::MissingTranslationData`. The valid case and deterministic custom
  validation (`permanent_duration_must_be_zero`) are covered. Testing presence, numericality, or
  inclusion validations on untranslated attributes requires locale manipulation or fixture-backed
  setup.
- **Command**:
  `bundle exec rails test test/models/chronicle_retention_policy_test.rb test/models/chronicle_outbox_entry_test.rb`
- **Decision**: **skipped** — only valid-path and custom-validation tests added

## 2026-06-12T12:40:00+00:00 — Batch 3: visitor email/telephone/token enum models

- **Targets**: `VisitorEmailStatus`, `VisitorTelephoneStatus`, `VisitorTokenBindingMethod`, `VisitorTokenStatus`
- **Files**: `test/models/visitor_email_status_test.rb`, `test/models/visitor_telephone_status_test.rb`,
  `test/models/visitor_token_binding_method_test.rb`, `test/models/visitor_token_status_test.rb`
- **Pattern**: Same as client/operator variants already tested. ReferenceRecord enums with constants
  (`NOTHING`, `ACTIVE`, etc.), `DEFAULTS` arrays, `nothing_id` method, `has_many` associations.
- **Verification**: 20 new runs, 42 new assertions. Full model suite: 2454 runs, 7373 assertions,
  1 failure (pre-existing `operator_secret_credential_test.rb:182`), 0 errors, 0 skips.
- **Command**:
  ```bash
  # Individual
  bundle exec rails test test/models/visitor_email_status_test.rb test/models/visitor_telephone_status_test.rb test/models/visitor_token_binding_method_test.rb test/models/visitor_token_status_test.rb

  # Full suite (serial to avoid timeout)
  PARALLEL_WORKERS=1 bundle exec rails test test/models
  ```
- **Decision**: **tested** — safe low-risk enums, parallel existing tested patterns

## 2026-06-12T12:40:00+00:00 — Note: pre-existing test failure observed

- **Target**: `operator_secret_credential_test.rb:162` —
  `test_usable_for_secret_credential_sign_in?_rejects_revoked_kind_and_expired_secret_credentials`
- **Reason**: This test failure was observed during `bundle exec rails test test/models`. The file
  was not modified. This is part of the 105 pre-existing baseline failures.
- **Command**: `bundle exec rails test test/models`
- **Decision**: **continued** — no action taken, pre-existing per baseline
