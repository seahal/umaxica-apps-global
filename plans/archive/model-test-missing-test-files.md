# Model Test Coverage — Part B: Missing Test Files

## Summary

57 of 368 model files have no test file. This plan creates test files for all non-abstract models in
that gap. The work is split into groups by pattern similarity to allow parallel execution.

Abstract base models (`AvatarRecord`, `CommerceRecord`, `MessageRecord`, `OperatorRecord`,
`PrincipalRecord`, `PublicationRecord`, `TokenRecord`) and `CustomerPreferenceRegionOption` are
excluded — they are not directly instantiated or have no testable behavior.

## Groups

### Group 1 — Business Logic Models (highest priority)

These have non-trivial constraints, scopes, or time-based logic.

| Model                  | Test file                                   | Key rules to cover                                                                                                                                                                                                                             |
| ---------------------- | ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CustomerPasskey`      | `test/models/customer_passkey_test.rb`      | `MAX_PASSKEYS_PER_CUSTOMER = 4`: below/at/above BVA; recovery identity required on create; `sign_count >= 0`; cascade delete with customer                                                                                                     |
| `CustomerSecret`       | `test/models/customer_secret_test.rb`       | `MAX_SECRETS_PER_CUSTOMER = 10`: below/at/above BVA; `name` max 255; expiry boundary inclusive/exclusive; `usable_for_secret_sign_in?` and `verify_for_secret_sign_in!`; limit isolation per customer                                          |
| `CustomerVerification` | `test/models/customer_verification_test.rb` | `token_digest` required and unique; `expires_at` required; `active?` true when not revoked and now < expires_at; `active?` false at exact expiry (boundary); `issue_for_token!` revokes all previous active verifications atomically           |
| `ReauthSession`        | `test/models/reauth_session_test.rb`        | `method` inclusion in `METHODS` list; invalid method rejected; `status` inclusion in `STATUSES` list; invalid status rejected; `expired?` false 1 second before expires_at; `expired?` true at exact expires_at; `attempt_count >= 0` enforced |
| `StaffOperator`        | `test/models/staff_operator_test.rb`        | `operator_id` uniqueness scoped to `staff_id`; same operator+staff rejected; same operator+different staff allowed                                                                                                                             |
| `UserMember`           | `test/models/user_member_test.rb`           | `member_id` uniqueness scoped to `user_id`; same member+user rejected; same member+different user allowed                                                                                                                                      |

### Group 2 — Preference Detail Models (12 models)

All follow the same pattern: `preference_id` uniqueness, `option_id` presence.

Models:

- `CustomerPreferenceColortheme`
- `CustomerPreferenceLanguage`
- `CustomerPreferenceRegion`
- `CustomerPreferenceTimezone`
- `StaffPreferenceColortheme`
- `StaffPreferenceLanguage`
- `StaffPreferenceRegion`
- `StaffPreferenceTimezone`
- `UserPreferenceColortheme`
- `UserPreferenceLanguage`
- `UserPreferenceRegion`
- `UserPreferenceTimezone`

Tests for each:

- Valid record: `preference_id` and `option_id` present
- `option_id` absent: invalid
- Second record with same `preference_id`: invalid (uniqueness)
- Second record with same `option_id` but different `preference_id`: valid

### Group 3 — Category/Tag Join Models (12 models)

All follow the same pattern: `belongs_to` two parents, uniqueness constraint on both foreign keys.

Models:

- `AppDocumentCategory`, `AppDocumentTag`
- `AppTimelineCategory`, `AppTimelineTag`
- `ComDocumentCategory`, `ComDocumentTag`
- `ComTimelineCategory`, `ComTimelineTag`
- `OrgDocumentCategory`, `OrgDocumentTag`
- `OrgTimelineCategory`, `OrgTimelineTag`

Tests for each:

- Valid record: both foreign keys present
- Missing parent foreign key: invalid
- Duplicate (same combination): invalid
- Different combination: valid

### Group 4 — Reference/Status Tables (11 models)

All follow the same pattern: integer constants defined, `has_many` with
`dependent: :restrict_with_error`.

Models:

- `CustomerEmailStatus`
- `CustomerPasskeyStatus`
- `CustomerSecretKind`
- `CustomerSecretStatus`
- `CustomerTelephoneStatus`
- `CustomerTokenBindingMethod`
- `CustomerTokenKind`
- `CustomerTokenStatus`
- `StaffSecretStatus`
- `StaffTokenKind`
- `UserTokenKind`

Tests for each:

- Each defined constant has the expected integer value
- `has_many` association is defined (verify `reflect_on_association` is not nil)

### Group 5 — Avatar/Content Models (3 models)

| Model              | Test file                               | Key rules                                                                                                                                  |
| ------------------ | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `AvatarPermission` | `test/models/avatar_permission_test.rb` | Constants `NOTHING/READ/WRITE/ADMIN` defined with expected values; `has_many` present                                                      |
| `AvatarRole`       | `test/models/avatar_role_test.rb`       | Constants `NOTHING/VIEWER/EDITOR/ADMIN` defined with expected values; `has_many` present                                                   |
| `PostVersion`      | `test/models/post_version_test.rb`      | `permalink` max 200 chars (200 valid, 201 invalid); `response_mode`, `published_at`, `expires_at` all required; `belongs_to :post` present |

### Group 6 — Message/Notification Join Models (4 models)

All include `PublicId` and have `belongs_to` associations.

Models:

- `MemberMessage`
- `MemberNotification`
- `OperatorMessage`
- `OperatorNotification`

Tests for each:

- Record is valid with all required associations present
- `PublicId` concern generates `public_id` on create
- Required association missing: invalid

## Implementation Notes

- Follow the test file and fixture patterns in existing tests. Use `user_passkey_test.rb` as a
  reference for limit enforcement patterns. Use `user_email_status_test.rb` for reference table
  patterns.
- Group 1 test files need fixtures for the parent model (customer, staff, user, operator, member).
  Reuse existing fixtures where they exist.
- Group 2–4 tests can use fixtures from parent fixtures or minimal `build` patterns without save
  where DB is not needed.
- No production code changes.
