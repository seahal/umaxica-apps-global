# Priority B - Controller `any_instance.stub` Migration Plan

## overview

The tests using Controller's `any_instance.stub` are set to Classical/London. School).

## Target file list

### Group 1: `refresh_token_expires_at` pattern (time manipulation type)

| #   | File path                                                              | Number of lines | stub target method          |
| --- | ---------------------------------------------------------------------- | --------------- | --------------------------- |
| 1   | `test/controllers/sign/app/edge/v0/token/refreshes_controller_test.rb` | 58, 62, 91, 95  | `:refresh_token_expires_at` |
| 2   | `test/controllers/sign/org/edge/v0/token/refreshes_controller_test.rb` | 71, 75          | `:refresh_token_expires_at` |
| 3   | `test/controllers/apex/app/web/v0/cookie_controller_test.rb`           | 71              | `:refresh_token_expires_at` |
| 4   | `test/controllers/apex/com/web/v0/cookie_controller_test.rb`           | 52              | `:refresh_token_expires_at` |
| 5   | `test/controllers/apex/org/web/v0/cookie_controller_test.rb`           | 57              | `:refresh_token_expires_at` |

**Conversion method**: Use TimeHelpers' `freeze_time` or `travel_to`

### Group 2: Verification type (step-up authentication)

| #   | File path                                                            | Number of lines     | stub target method                                                              |
| --- | -------------------------------------------------------------------- | ------------------- | ------------------------------------------------------------------------------- |
| 1   | `test/controllers/sign/org/verification/passkeys_controller_test.rb` | 27-29               | `:available_step_up_methods`, `:prepare_passkey_challenge!`, `:verify_passkey!` |
| 2   | `test/controllers/sign/app/verification/passkeys_controller_test.rb` | 20-22, 42-43        | `:available_step_up_methods`, `:prepare_passkey_challenge!`, `:verify_passkey!` |
| 3   | `test/controllers/sign/app/verification/emails_controller_test.rb`   | 27-28, 44, 59-60... | `:available_step_up_methods`, `:send_email_otp!`, `:verify_email_otp!`          |
| 4   | `test/integration/org_verification_flow_test.rb`                     | 39, 55-57           | Same as above                                                                   |
| 5   | `test/integration/org_step_up_verification_enforcer_test.rb`         | 94-96               | Same as above                                                                   |
| 6   | `test/integration/verification_flow_test.rb`                         | 59-61               | Same as above                                                                   |
| 7   | `test/integration/verification_sessions_test.rb`                     | 59                  | `:verify_totp!`                                                                 |

**Conversion method**: Dependency injection into the Service layer or test with actual request
response

### Group 3: Login/authentication results system

| #   | File path                                                              | Number of lines | stub target method                                   |
| --- | ---------------------------------------------------------------------- | --------------- | ---------------------------------------------------- |
| 1   | `test/controllers/sign/org/in/secrets_controller_test.rb`              | 160             | `:log_in`                                            |
| 2   | `test/controllers/sign/org/in/passkeys_controller_test.rb`             | 135, 262        | Multiple methods                                     |
| 3   | `test/controllers/sign/app/in/passkeys_controller_test.rb`             | 351, 378        | `:complete_sign_in_or_start_mfa!`, `:with_challenge` |
| 4   | `test/controllers/sign/org/auth/omniauth_callbacks_controller_test.rb` | 99              | Login related                                        |

**Conversion method**: Mocking the Service layer or validating in database state

### Group 4: Phone number registration system

| #   | File path                                                                             | Number of lines         | stub target method                                                          |
| --- | ------------------------------------------------------------------------------------- | ----------------------- | --------------------------------------------------------------------------- |
| 1   | `test/controllers/sign/org/configuration/telephones/registrations_controller_test.rb` | 63, 67                  | `:current_registration_telephone`, `:complete_staff_telephone_verification` |
| 2   | `test/controllers/sign/app/configuration/telephones/registrations_controller_test.rb` | 154, 178, 201, 224, 241 | Same as above + `set_registration_session`                                  |

**Conversion method**: Alternative implementation of session operations or testing in real flow

### Group 5: Individual cases

| #   | File path                                                             | Number of lines | stub target method                           |
| --- | --------------------------------------------------------------------- | --------------- | -------------------------------------------- |
| 1   | `test/controllers/sign/org/configuration/passkeys_controller_test.rb` | 103             | `OperatorPasskey.any_instance.stub(:valid?)` |
| 2   | `test/controllers/apex/app/web/v0/cookie_controller_test.rb`          | 141             | `:issue_access_token_from`                   |

## conversion strategy

### Strategy A: Time manipulation with TimeHelpers (group 1)

**Current code**:

```ruby
controller = Sign::App::Edge::V0::Token::RefreshesController
expires_at = Time.utc(2034, 4, 5, 6, 7, 8)

controller.any_instance.stub(:refresh_token_expires_at, expires_at) do
  post "/edge/v0/token/refresh", ...
end

assert_in_delta expires_at.to_i, response_cookie_expiry("preference_consented").to_i, 1
```

**Code after conversion**:

```ruby
freeze_time do
  expires_at = Time.utc(2034, 4, 5, 6, 7, 8)

  travel_to(expires_at) do
    post "/edge/v0/token/refresh", ...
  end

  assert_in_delta expires_at.to_i, response_cookie_expiry("preference_consented").to_i, 1
end
```

**procedure**:

1. Check if `test/test_helper.rb` includes `ActiveSupport::Testing::TimeHelpers`
2. Wrap the entire test with `freeze_time`
3. Set the stub time value with `travel_to`
4. Expected value also uses the same time value

### Strategy B: Cutting out to the Service layer (Group 2, 3)

**Current code**:

```ruby
Sign::App::Verification::BaseController.any_instance.stub(:available_step_up_methods, [:passkey]) do
  Sign::App::Verification::PasskeysController.any_instance.stub(:prepare_passkey_challenge!, true) do
    Sign::App::Verification::PasskeysController.any_instance.stub(:verify_passkey!, true) do
      get sign_app_verification_url(...)
    end
  end
end
```

**Post-conversion approaches (options)**:

**Option B1: Test with actual flow as integration test**

```ruby
test "creates verification on success via real flow" do
  return_to = Base64.urlsafe_encode64(sign_app_configuration_passkeys_path(ri: "jp"))

  # Execute the actual step-up authentication flow
  user = users_with_passkey(:one) # Prepare fixture with passkey

  get sign_app_verification_url(scope: "configuration_passkey", return_to: return_to), ...

  follow_redirect!
  assert_response :success

  post sign_app_verification_passkey_url, params: {
    credential: valid_passkey_credential_for(user)
  }

  assert_response :redirect
  assert_redirected_to sign_app_configuration_passkeys_url(ri: "jp")
end
```

**Option B2: Mocking the Service layer**

```ruby
test "creates verification on success with service mock" do
  return_to = Base64.urlsafe_encode64(sign_app_configuration_passkeys_path(ri: "jp"))

  # Mock Service method
  mock_service = Minitest::Mock.new
  mock_service.expect :call, true, [User, String, Hash]

  Sign::App::PasskeyVerificationService.stub :verify!, mock_service do
    get sign_app_verification_url(scope: "configuration_passkey", return_to: return_to), ...

    get new_sign_app_verification_passkey_url(ri: "jp"), ...

    post sign_app_verification_passkey_url(ri: "jp"), ...
  end

  mock_service.verify
end
```

### Strategy C: Database-dependent testing (groups 3, 4)

**Pattern**: Case where authentication results are stubbed

**Current code**:

```ruby
Sign::Org::In::SecretsController.any_instance.stub(:log_in, { status: :unknown }) do
  post sign_org_in_secret_url(ri: "jp"), ...
end
```

**Code after conversion**:

```ruby
test "create renders invalid when login fails" do
  # Use invalid credentials
  post sign_org_in_secret_url(ri: "jp"),
       params: { secret_login_form: {
         identifier: @staff.public_id,
         secret_value: "invalid-secret"
       } }

  assert_response :unprocessable_content
  assert_includes response.body, I18n.t("sign.org.authentication.secret.create.invalid")
end
```

### Strategy D: Session Manipulation Alternatives (Group 4)

**Current code**:

```ruby
def set_registration_session(id)
  Sign::App::Configuration::Telephones::RegistrationsController.any_instance.stub(
    :current_registration_telephone,
    UserTelephone.find(id),
  ) do
    yield if block_given?
  end
end
```

**Code after conversion**:

```ruby
def set_registration_session(telephone)
  # Save to actual session
  post sign_app_configuration_telephones_registrations_path(ri: "jp"),
       params: { user_telephone: { raw_number: telephone.raw_number } }
  assert_response :redirect # Confirmation code sent successfully
end
```

## Implementation steps

### Phase 1: Infrastructure development (0.5 days)

- [ ] include `ActiveSupport::Testing::TimeHelpers` in `test/test_helper.rb`
- [ ] Add necessary helper methods
- [ ] Operation confirmation in CI environment

### Phase 2: Group 1 (time manipulation system) migration (1 day)

- [ ] `sign/app/edge/v0/token/refreshes_controller_test.rb`
- [ ] `sign/org/edge/v0/token/refreshes_controller_test.rb`
- [ ] `apex/*/web/v0/cookie_controller_test.rb` (3 files)

**Review points**:

- Is time fixing using TimeHelpers working correctly?
- Is the cookie's expires attribute set as expected?

### Phase 3: Group 5 (individual case) (0.5 days)

- [ ] `sign/org/configuration/passkeys_controller_test.rb` - stub to `OperatorPasskey`
- [ ] `apex/app/web/v0/cookie_controller_test.rb` - line 141

### Phase 4: Group 4 (phone number registration) (1 day)

- [ ] Rewritten to test with actual session flow
- [ ] Alternative implementation of `set_registration_session` helper

**Review points**:

- Do session-based flows work correctly?
- Are error cases covered?

### Phase 5: Group 2 (Verification) (2 days)

- [ ] Passkey verification
- [ ] Email OTP verification
- [ ] TOTP verification
- [ ] Alternative to BaseController method stub

**Review points**:

- Properly separate dependencies on external services (WebAuthn)
- Does the actual flow work as an integration test?

### Phase 6: Group 3 (Login/Authentication) (1.5 days)

- [ ] SecretsController
- [ ] PasskeysController (both app/org)
- [ ] OmniauthCallbacksController

**Review points**:

- Is extraction to the Service layer appropriate?
- Coverage of error cases

### Phase 7: Overall consistency and CI confirmation (1 day)

- [ ] Verify that all tests pass
- [ ] Check whether the test execution time has worsened.
- [ ] Check coverage report

## Risks and countermeasures

| Risk                                                    | Impact | Countermeasures                                                                                 |
| ------------------------------------------------------- | ------ | ----------------------------------------------------------------------------------------------- |
| Time zone issues when using TimeHelpers                 | Medium | Explicitly use UTC and avoid converting to Japan time                                           |
| Requires design changes due to service layer extraction | High   | Develop extraction plan as a separate task; this task only replaces the stub                    |
| Test instability due to actual WebAuthn call            | High   | Maintain the WebAuthn mock and delete only the Controller stub                                  |
| Increasing complexity of session operation tests        | Medium | Enriching helper methods to ensure readability                                                  |
| Increased test execution time                           | Medium | Check whether the increase due to changes in actual DB operations is within an acceptable range |

## success criteria

1. All `any_instance.stub` are deleted
2. Existing test coverage is maintained
3. Test execution time does not deteriorate by more than 20%
4. All CI checks pass

## Precautions

- **Never Do**: `send(:method_name)` calls to Controller private methods
- **Patterns to avoid**: Complex conditional branches in tests
- **Preferred pattern**: Validation on actual request/response cycles
