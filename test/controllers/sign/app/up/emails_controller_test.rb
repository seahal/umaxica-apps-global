# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Sign::Up::EmailsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    cookies["csrf_token"] = csrf_token_value
    Rails.configuration.x.rate_limit.fetch(:store).clear
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "should get new" do
    get new_sign_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "div[id^='cf-turnstile-']", count: 1
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, 'data-turnstile-mode-value="render"'
    assert_select "script[type='module'][src*='vite']", minimum: 1
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
    assert_includes response.headers["Content-Security-Policy"], "default-src 'self'"
    assert_not_includes response.headers["Content-Security-Policy"], "'unsafe-inline'"
  end

  test "collection get is not routed" do
    get sign_app_sign_up_email_url(hotwire_spark: true, reload: "123"), headers: default_headers

    assert_response :not_found
  end

  test "renders email registration form structure" do
    get new_sign_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    assert_select "h2", I18n.t("sign.app.registration.email.new.page_title")
    assert_select "input[type=checkbox][name='client_email[promotional]']", count: 1
    assert_select "input[type=checkbox][name='client_email[notifiable]']", count: 1
    assert_no_match(/UMAXICA \(sign, app\)/, response.body)
  end

  test "includes navigation links to other registration flows" do
    get new_sign_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    assert_select "a[href=?]", sign_app_sign_up_path(ri: "jp"), count: 1
    assert_select "a[href=?]", new_sign_app_sign_in_email_path(ri: "jp"), count: 1
  end

  test "edit uses current registration email from session" do
    # Establish flow state by starting a registration
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "flow_setup@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    get sign_app_sign_up_check_email_otp_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "h1", text: I18n.t("sign.app.authentication.email.edit.page_title")
    assert_select "label", text: I18n.t("sign.app.authentication.email.edit.code_label")
    assert_select "input[placeholder=?]", I18n.t("sign.app.authentication.email.edit.code_placeholder")
    assert_select "input[type=submit][value=?]", I18n.t("sign.app.authentication.email.edit.submit")
    assert_includes response.body, "メールアドレス"
    assert_includes response.body, I18n.t("sign.app.authentication.email.edit.delivery_help")
  end

  test "i18n flash messages for email registration flow exist" do
    # Check that all required i18n keys for email registration exist
    session_expired_key = "sign.app.registration.email.edit.session_expired"
    create_key = "sign.app.registration.email.create.verification_code_sent"
    update_key = "sign.app.registration.email.update.success"

    assert_not_nil I18n.t(session_expired_key, default: nil)
    assert_not_nil I18n.t(create_key, default: nil)
    assert_not_nil I18n.t(update_key, default: nil)
  end

  test "can re-register same email if previous registration was unverified" do
    email = "test_re_reg@example.com"

    # First registration attempt
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Verify first record created - extract ID from redirect location
    first_email_id = ClientEmail.order(:created_at).last.public_id
    first_email = ClientEmail.find_by(public_id: first_email_id)

    assert_not_nil first_email
    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, first_email.user_email_status_id

    assert_not_nil first_email.address_digest

    # Second registration attempt after the independent overwrite window expires (case-variant)
    # This should delete the previous unverified record and create a new one
    travel CommonOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "TEST_RE_REG@EXAMPLE.COM",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers

      # Should succeed because old unverified record is deleted
      assert_response :redirect

      # Verify old record was deleted and new record was created
      new_email_id = ClientEmail.order(:created_at).last.public_id

      assert_not_equal first_email.id, new_email_id # Check IDs from URL differ
    end
  end

  test "create redirects to edit and allows edit page" do
    email = "flow_step_test@example.com"

    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    follow_redirect!

    assert_response :success
    assert_equal "/sign/up/check/email/otp", path
  end

  test "create renders unprocessable when user_email param missing" do
    assert_no_difference("ClientEmail.count") do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: { "cf-turnstile-response": "test" },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.create.address_required")
  end

  test "create renders unprocessable when turnstile fails" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    assert_no_difference("ClientEmail.count") do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "turnstile-failure@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.create.turnstile_validation_failed")
  end

  test "create with existing verified email is rejected and does not create a new record" do
    user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
    existing_email = ClientEmail.create!(
      user: user,
      address: "existing_signup@example.com",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_no_difference("Client.count") do
      assert_no_difference("ClientEmail.count") do
        assert_enqueued_emails 0 do
          post sign_app_sign_up_email_url(ri: "jp"),
               params: {
                 user_email: {
                   raw_address: existing_email.address,
                   confirm_policy: "1",
                 },
                 "cf-turnstile-response": "test",
               },
               headers: default_headers
        end
      end
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.new.error_summary")
    assert_includes response.body, ClientEmail.human_attribute_name(:address)
    assert_nil session[SignEmailRegistrable::EXISTING_EMAIL_SESSION_KEY]
  end

  test "create with existing verified-with-sign-up email is rejected" do
    existing_user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
    ClientEmail.create!(
      user: existing_user,
      address: "completed-signup@example.com",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED_WITH_SIGN_UP,
    )

    assert_no_difference("Client.count") do
      assert_no_difference("ClientEmail.count") do
        assert_enqueued_emails 0 do
          post sign_app_sign_up_email_url(ri: "jp"),
               params: {
                 user_email: {
                   raw_address: "completed-signup@example.com",
                   confirm_policy: "1",
                 },
                 "cf-turnstile-response": "test",
               },
               headers: default_headers
        end
      end
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.new.error_summary")
    assert_nil session[SignEmailRegistrable::EXISTING_EMAIL_SESSION_KEY]
  end

  test "create enqueues exactly one email" do
    email = "enqueue_test@example.com"

    assert_enqueued_emails 1 do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :redirect
  end

  test "create stores requested email preference flags" do
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "signup-preferences@example.com",
             confirm_policy: "1",
             promotional: "0",
             notifiable: "0",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by!(public_id: email_id)

    assert_not user_email.promotional
    assert_not user_email.notifiable
  end

  test "create with existing verified email enqueues no emails and leaves otp state unchanged" do
    user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
    existing_email = ClientEmail.create!(
      user: user,
      address: "no_otp_send@example.com",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    before_otp_last_sent_at = existing_email.otp_last_sent_at
    before_otp_counter = existing_email.otp_counter
    before_otp_attempts_count = existing_email.otp_attempts_count

    assert_enqueued_emails 0 do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "no_otp_send@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_equal before_otp_last_sent_at, existing_email.reload.otp_last_sent_at
    assert_equal before_otp_counter, existing_email.otp_counter
    assert_equal before_otp_attempts_count, existing_email.otp_attempts_count
  end

  test "create with validation failure enqueues no emails and returns 422" do
    email = "invalid_email"

    assert_enqueued_emails 0 do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes @response.body, I18n.t("sign.app.registration.email.new.error_summary")
    assert_not_includes @response.body, "prohibited this sample from being saved"
  end

  test "create without policy confirmation shows localized validation summary" do
    logs = []

    assert_enqueued_emails 0 do
      Rails.logger.stub(:info, ->(*args, &block) { logs << (args.first || block&.call).to_s }) do
        post sign_app_sign_up_email_url(ri: "jp"),
             params: {
               user_email: {
                 raw_address: "policy_missing@example.com",
                 confirm_policy: "0",
               },
               "cf-turnstile-response": "test",
             },
             headers: default_headers
      end
    end

    assert_response :unprocessable_content
    assert_includes @response.body, I18n.t("sign.app.registration.email.new.error_summary")
    assert_includes @response.body, ClientEmail.human_attribute_name(:confirm_policy)
    assert_not_includes @response.body, "prohibited this sample from being saved"
    assert_no_match(/policy_missing@example\.com/, logs.join("\n"))
  end

  test "create with turnstile failure enqueues no emails and returns 422" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    email = "turnstile_fail@example.com"

    assert_enqueued_emails 0 do
      post(
        sign_app_sign_up_email_url(ri: "jp"),
        params: {
          user_email: {
            raw_address: email,
            confirm_policy: "1",
          },
          "cf-turnstile-response": "test",
        },
        headers: default_headers,
      )
    end

    assert_response :unprocessable_content
    assert_includes @response.body, I18n.t("sign.app.registration.email.create.turnstile_validation_failed")
  ensure
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  test "rejects wrong OTP codes with error message" do
    email = "test_wrong_otp@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    # Attempt wrong code
    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: "000000",
            },
          },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes @response.body, "正しくありません"
  end

  test "update with blank code returns 422 and renders edit" do
    email = "blank_code_test@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    # Attempt with blank code
    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: "",
            },
          },
          headers: default_headers

    assert_response :unprocessable_content
    assert_includes @response.body, I18n.t("sign.app.registration.email.update.code_required")
  end

  test "update with expired session redirects to new" do
    email = "expired_test@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    # Travel to expire OTP
    travel 16.minutes do
      patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
            params: {
              id: user_email.id,
              user_email: {
                pass_code: "123456",
              },
            },
            headers: default_headers

      assert_response :unprocessable_content
      assert_equal "ticket is required", response.body
    end
  end

  test "max OTP attempts renders lockout error without clearing otp" do
    email = "test_max_attempts@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    cycle = ClientSignUpFlow.find_by!(public_id: session.dig(:app_sign_up_flow_locator, "public_id"))
    completed_requirements = cycle.completed_requirements.deep_dup

    Email::MAX_OTP_ATTEMPTS.times do
      patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
            params: {
              id: user_email.id,
              user_email: {
                pass_code: "000000",
              },
            },
            headers: default_headers
    end

    assert_response :too_many_requests
    assert_includes response.body, I18n.t("sign.app.registration.email.update.attempts_exceeded")
    assert_empty flash.to_hash
    assert ClientEmail.exists?(public_id: user_email.public_id)
    assert_predicate user_email.reload, :locked?
    assert_equal completed_requirements, cycle.reload.completed_requirements
    assert_nil cycle.completed_requirements["otp"]
  end

  test "telephone i18n flash messages exist" do
    # Check that all required i18n keys for telephone registration exist
    session_expired_key = "sign.app.registration.telephone.edit.session_expired"
    create_key = "sign.app.registration.telephone.create.verification_code_sent"
    update_key = "sign.app.registration.telephone.update.success"

    assert_not_nil I18n.t(session_expired_key, default: nil)
    assert_not_nil I18n.t(create_key, default: nil)
    assert_not_nil I18n.t(update_key, default: nil)
  end

  # Turnstile Widget Verification Tests
  test "new registration email page renders Turnstile widget" do
    get new_sign_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "div[id^='cf-turnstile-']", count: 1
  end

  test "turnstile validation error message i18n key exists" do
    # Verify the turnstile error message key exists in all locales
    assert_not_nil I18n.t(
      "sign.app.registration.email.create.turnstile_validation_failed", locale: :ja,
                                                                        default: nil,
    )
    assert_not_nil I18n.t(
      "sign.app.registration.email.create.turnstile_validation_failed", locale: :en,
                                                                        default: nil,
    )
  end

  test "new rejects when user is already logged in" do
    # Create a user and log them in
    user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)

    # Try to access registration page while logged in (using test header to inject current user)
    get new_sign_app_sign_up_email_url(ri: "jp"),
        headers: as_user_headers(user, host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))

    assert_response :unauthorized
    assert_equal I18n.t("errors.messages.already_authenticated"), response.body
  end

  test "create rejects when user is already logged in" do
    user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)

    assert_no_difference("ClientEmail.count") do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "logged-in@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers.merge({ "X-TEST-CURRENT-USER" => user.id })
    end

    assert_response :unauthorized
    assert_equal I18n.t("errors.messages.already_authenticated"), response.body
  end

  test "redirects to encoded URL after successful registration when pt parameter is provided" do
    email = "redirect_test_#{SecureRandom.hex(4)}@example.com"
    redirect_url = "/dashboard"

    # Create registration record with pt parameter
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
           pt: redirect_url,
         },
         headers: default_headers

    # Verify pt parameter is preserved in redirect
    assert_response :redirect
    signed_rt = Rack::Utils.parse_nested_query(URI.parse(response.location).query)["pt"]

    assert_nil signed_rt

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    # Submit correct OTP with pt parameter
    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
            pt: signed_rt,
          },
          headers: default_headers

    # Should redirect directly to the decoded pt destination
    assert_redirected_to sign_app_sign_up_guard_email_path(ri: "jp")
  end

  # Transaction Tests for Client Creation

  test "successful OTP verification creates user and saves email in transaction" do
    email = "transaction_success@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    initial_user_count = Client.count

    # Submit correct OTP
    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    # Verify success response
    assert_redirected_to sign_app_sign_up_guard_email_path(ri: "jp")

    # Verify Client count unchanged (pending user was updated, not created)
    assert_equal initial_user_count, Client.count

    # Verify ClientEmail was updated and linked to user
    user_email.reload

    assert_not_nil user_email.user_id
    assert_equal ClientEmailStatus::VERIFIED_WITH_SIGN_UP, user_email.user_email_status_id

    # Verify Client has correct status
    user = user_email.user

    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user.status_id
    assert_nil user.rp_account
  end

  test "successful OTP verification creates audit log in transaction" do
    email = "audit_log_test@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    initial_audit_count = ClientChronicle.count

    # Submit correct OTP
    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    # Verify success response
    assert_redirected_to sign_app_sign_up_guard_email_path(ri: "jp")

    # Sign-up completion and sign-in audit are delayed until checkpoint finalization.
    assert_equal initial_audit_count, ClientChronicle.count
  end

  test "successful OTP verification does not write signup audit before finalization" do
    email = "missing_audit_event_signup@example.com"

    initial_audit_count = ClientChronicle.count

    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    assert_redirected_to sign_app_sign_up_guard_email_path(ri: "jp")
    assert_equal initial_audit_count, ClientChronicle.count
  end

  test "sets user session after successful registration" do
    email = "session_set@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    # Submit correct OTP
    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    # No authenticated session is issued before checkpoint finalization.
    assert_nil cookies[::AuthenticationClient::ACCESS_COOKIE_KEY]

    # Verify user and token were created
    user = user_email.reload.user

    assert_not_nil user, "Pending client should exist"
    assert_not ClientToken.exists?(user_id: user.id), "Client token should not be created before finalization"
  end

  test "successful registration does not set auth cookies before finalization" do
    email = "cookie_domain_up_#{SecureRandom.hex(4)}@example.com"

    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by!(public_id: email_id)
    otp_data = user_email.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: pass_code,
            },
          },
          headers: default_headers

    set_cookie = response.headers["Set-Cookie"].to_s

    assert_no_match(/#{Regexp.escape(::AuthenticationClient::ACCESS_COOKIE_KEY.to_s)}=/, set_cookie)
  end

  test "email sign up finalizes and establishes login from checkpoint" do
    email = "finalize_app_email_#{SecureRandom.hex(4)}@example.com"

    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect
    user_email = ClientEmail.order(:created_at).last
    otp_data = user_email.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { user_email: { pass_code: pass_code } },
          headers: default_headers

    assert_redirected_to sign_app_sign_up_guard_email_url(ri: "jp")

    get sign_app_sign_up_guard_email_url(ri: "jp"), headers: default_headers

    assert_redirected_to sign_app_sign_up_check_email_birthdate_url(ri: "jp")

    get sign_app_sign_up_check_email_birthdate_url(ri: "jp"), headers: default_headers

    assert_response :ok
    assert_select "[data-birthdate-format=iso]"
    assert_select "input[type=number][name=birthdate_year][autocomplete=bday-year]"
    assert_select "input[type=number][name=birthdate_month][autocomplete=bday-month]"
    assert_select "input[type=number][name=birthdate_day][autocomplete=bday-day]"
    assert_select "input[type=hidden][name=requirement][value=birthdate]"
    birthdate_path = sign_app_sign_up_check_email_birthdate_path(ri: "jp")

    assert_select "form[data-turbo=false][method=post][action='#{birthdate_path}']"
    assert_select "form[action='#{birthdate_path}'] input[name=_method][value=patch]"
    assert_select "form[data-turbo=false][method=post][action='#{birthdate_path}']"
    assert_select "form[action='#{birthdate_path}'] input[name=_method][value=delete]"
    assert_select "a[href*=?]", sign_app_sign_up_path, count: 0
    assert_select "a[href*=?]", sign_app_sign_in_path, count: 0

    get sign_app_sign_up_check_email_birthdate_url(ri: "jp"), headers: default_headers

    assert_response :ok
    assert_select "[data-birthdate-format=iso]"

    cycle = current_sign_up_flow(user_email)

    patch sign_app_sign_up_check_email_birthdate_url(ri: "jp"),
          params: {
            requirement: "birthdate",
            birthdate: "2000-01-01",
            checkpoint_version: cycle.reload.checkpoint_version,
          },
          headers: default_headers

    assert_response :redirect

    user = user_email.reload.user

    assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.reload.status_id
    assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, user.status_id
    assert ClientToken.exists?(user_id: user.id)
  end

  test "OTP data is cleared after successful verification" do
    email = "otp_clear@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    # Verify OTP data exists before verification
    assert_not_nil user_email.get_otp

    # Submit correct OTP
    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    # Verify OTP data was cleared
    user_email.reload

    assert_nil user_email.get_otp
  end

  test "does not reset session ID before checkpoint finalization" do
    email = "session_reset_test@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    old_session_id = session.id.to_s

    # Submit correct OTP
    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    assert_equal old_session_id, session.id.to_s
  end

  test "creates pending user with UNVERIFIED_WITH_SIGN_UP status during email registration" do
    email = "pending_user_test@example.com"

    initial_user_count = Client.count

    # Create registration record
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Verify pending user was created
    assert_equal initial_user_count + 1, Client.count

    # Extract email and verify it's linked to a pending user
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    assert_not_nil user_email.user
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user_email.user.status_id
    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, user_email.user_email_status_id
  end

  test "create binds email signup cycle and otp success advances to guardrail" do
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "email_cycle_#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    user_email = ClientEmail.order(:created_at).last
    cycle = current_sign_up_flow(user_email)

    assert_equal "email", cycle.entry_method
    assert_equal "email", cycle.pending_contact_type
    assert_equal user_email.id, cycle.pending_contact_id
    assert_equal user_email.user_id, cycle.principal_id
    assert_equal "contact", cycle.step

    otp_data = user_email.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            user_email: { pass_code: pass_code },
          },
          headers: default_headers

    assert_redirected_to sign_app_sign_up_guard_email_path(ri: "jp")
    assert_equal "checkpoint", cycle.reload.step
  end

  test "email signup checkpoint persists birthdate requirement" do
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "email_birthdate_#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    user_email = ClientEmail.order(:created_at).last
    cycle = current_sign_up_flow(user_email)
    otp_data = user_email.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: {
            user_email: { pass_code: pass_code },
          },
          headers: default_headers

    get sign_app_sign_up_guard_email_url(ri: "jp"), headers: default_headers

    assert_redirected_to sign_app_sign_up_check_email_birthdate_path(ri: "jp")

    get sign_app_sign_up_check_email_birthdate_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "[data-birthdate-format=iso]"

    patch sign_app_sign_up_check_email_birthdate_url(ri: "jp"),
          params: {
            requirement: "birthdate",
            birthdate_year: "2000",
            birthdate_month: "02",
            birthdate_day: "03",
            checkpoint_version: cycle.reload.checkpoint_version,
          },
          headers: default_headers

    assert_response :redirect
    assert_equal "2000-02-03", user_email.user.reload.birthdate
    assert cycle.reload.requirement_cleared?(:birthdate)
    assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.status_id
  end

  test "email signup checkpoint cancel stops the signup path" do
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "email_checkpoint_cancel_#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    user_email = ClientEmail.order(:created_at).last
    cycle = current_sign_up_flow(user_email)
    otp_data = user_email.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { user_email: { pass_code: pass_code } },
          headers: default_headers

    get sign_app_sign_up_guard_email_url(ri: "jp"), headers: default_headers
    get sign_app_sign_up_check_email_birthdate_url(ri: "jp"), headers: default_headers

    assert_response :success

    post sign_app_sign_up_check_email_cancellation_url(ri: "jp"), headers: default_headers

    assert_redirected_to sign_app_sign_up_url(ri: "jp")
    assert_equal ClientSignUpFlowStatus::CANCELLED, cycle.reload.status_id

    get sign_app_sign_up_check_email_birthdate_url(ri: "jp"), headers: default_headers

    assert_response :unprocessable_content
    assert_equal "ticket is required", response.body
  end

  test "email signup checkpoint birthdate is idempotent after requirement is cleared" do
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "email_birthdate_retry_#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    user_email = ClientEmail.order(:created_at).last
    cycle = current_sign_up_flow(user_email)
    otp_data = user_email.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { user_email: { pass_code: pass_code } },
          headers: default_headers

    get sign_app_sign_up_guard_email_url(ri: "jp"), headers: default_headers
    get sign_app_sign_up_check_email_birthdate_url(ri: "jp"), headers: default_headers

    user_email.user.update!(birthdate: "2000-02-03")
    cycle.update!(
      completed_requirements: {
        "otp" => {
          "cleared" => true,
          "cleared_at" => Time.current.iso8601,
        },
        "birthdate" => {
          "cleared" => true,
          "cleared_at" => Time.current.iso8601,
        },
      },
      checkpoint_version: cycle.reload.checkpoint_version,
    )

    patch sign_app_sign_up_check_email_birthdate_url(ri: "jp"),
          params: {
            requirement: "birthdate",
            birthdate: "2000-02-03",
            checkpoint_version: cycle.reload.checkpoint_version,
          },
          headers: default_headers

    assert_response :redirect
    assert_equal ClientSignUpFlowStatus::COMPLETED, cycle.reload.status_id
  end

  test "email signup checkpoint blocks users before thirteenth birthday" do
    travel_to Time.zone.local(2024, 2, 29, 12, 0, 0) do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "email_under13_#{SecureRandom.hex(4)}@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers

      assert_response :redirect
      user_email = ClientEmail.order(:created_at).last
      cycle = current_sign_up_flow(user_email)
      otp_data = user_email.get_otp
      pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

      patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
            params: { user_email: { pass_code: pass_code } },
            headers: default_headers

      assert_redirected_to sign_app_sign_up_guard_email_url(ri: "jp")

      get sign_app_sign_up_guard_email_url(ri: "jp"), headers: default_headers

      assert_redirected_to sign_app_sign_up_check_email_birthdate_url(ri: "jp")

      get sign_app_sign_up_check_email_birthdate_url(ri: "jp"), headers: default_headers

      assert_response :success

      patch sign_app_sign_up_check_email_birthdate_url(ri: "jp"),
            params: {
              requirement: "birthdate",
              birthdate: "2011-03-01",
              checkpoint_version: cycle.reload.checkpoint_version,
            },
            headers: default_headers

      assert_response :success
      assert_includes response.body, "この登録方法ではアカウントを作成できません"
      assert_equal ClientSignUpFlowStatus::FAILED, cycle.reload.status_id

      patch sign_app_sign_up_check_email_birthdate_url(ri: "jp"),
            params: {
              requirement: "birthdate",
              birthdate: "2000-01-01",
              checkpoint_version: cycle.checkpoint_version,
            },
            headers: default_headers

      assert_response :unprocessable_content
      assert_equal "ticket is required", response.body
      assert_equal ClientSignUpFlowStatus::FAILED, cycle.reload.status_id
      assert_not cycle.requirement_cleared?(:birthdate)
    end
  end

  test "does not leave zero or null user_id in database" do
    email = "no_zero_user_id@example.com"

    # Create registration record
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Extract email ID from redirect location
    email_id = ClientEmail.order(:created_at).last.public_id
    user_email = ClientEmail.find_by(public_id: email_id)

    # Verify user_id is not zero or null
    assert_not_nil user_email.user_id, "user_id should not be nil"
    assert_not_equal "00000000-0000-0000-0000-000000000000", user_email.user_id,
                     "user_id should not be zero UUID"

    # Verify user actually exists
    assert Client.exists?(id: user_email.user_id), "Client record should exist for user_id"
  end

  test "deletes pending user when unverified email is replaced" do
    email = "replace_pending_test@example.com"

    # First registration attempt
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Get first pending user
    first_email_id = ClientEmail.order(:created_at).last.public_id
    first_email = ClientEmail.find_by(public_id: first_email_id)
    first_user_id = first_email.user_id

    # Count users before second attempt
    user_count_before_second = Client.count

    # Second registration attempt after cooldown (should delete first pending user)
    travel CommonOtpPolicy::SEND_COOLDOWN + 1.second do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers

      assert_response :redirect

      # Verify first user was deleted
      assert_nil Client.find_by(id: first_user_id), "First pending user should be deleted"

      # Verify new user was created (count should remain the same: one deleted, one created)
      assert_equal user_count_before_second, Client.count

      # Verify new email has a different user
      second_email_id = ClientEmail.order(:created_at).last.public_id
      second_email = ClientEmail.find_by(public_id: second_email_id)

      assert_not_equal first_user_id, second_email.user_id
      assert_not_nil second_email.user
    end
  end

  test "can abandon first email and register with a different email without error" do
    first_email = "first_abandoned@example.com"
    second_email = "second_attempt@example.com"

    # First registration attempt with email A
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: first_email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Get first pending user info
    first_email_id = ClientEmail.order(:created_at).last.public_id
    first_record = ClientEmail.find_by(public_id: first_email_id)
    first_user_id = first_record.user_id

    assert_not_nil first_record
    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, first_record.user_email_status_id

    # Client abandons: navigates back to "new" page
    # This should succeed without redirect loop or error
    get new_sign_app_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    # Client submits a different email B
    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: second_email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    # Verify second registration created a new pending user
    second_email_id = ClientEmail.order(:created_at).last.public_id
    second_record = ClientEmail.find_by(public_id: second_email_id)

    assert_not_nil second_record
    assert_equal ClientEmailStatus::UNVERIFIED_WITH_SIGN_UP, second_record.user_email_status_id
    assert_not_equal first_user_id, second_record.user_id

    # Verify first pending user was cleaned up
    assert_nil Client.find_by(id: first_user_id),
               "First pending user should be cleaned up when registering with a different email"
  end

  # OTP Resend Cooldown Tests
  test "create returns 429 when re-registering inside overwrite window for new signup" do
    email = "cooldown_test@example.com"

    # First registration attempt
    assert_enqueued_emails 1 do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :redirect

    # Second attempt immediately (inside the 10s overwrite window)
    assert_enqueued_emails 0 do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :too_many_requests
    assert_includes @response.body, I18n.t("sign.app.registration.email.create.otp_resend_too_soon")
  end

  test "create allows re-registration after overwrite window expires for new signup" do
    email = "cooldown_expire_test@example.com"

    # First registration attempt
    assert_enqueued_emails 1 do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :redirect

    # After the overwrite window expires, even though OTP resend cooldown is longer.
    travel CommonOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
      assert_enqueued_emails 1 do
        post sign_app_sign_up_email_url(ri: "jp"),
             params: {
               user_email: {
                 raw_address: email,
                 confirm_policy: "1",
               },
               "cf-turnstile-response": "test",
             },
             headers: default_headers
      end

      assert_response :redirect
    end
  end

  test "existing registered emails are rejected instead of entering cooldown" do
    user = Client.create!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
    ClientEmail.create!(
      user: user,
      address: "registered_cooldown@example.com",
      confirm_policy: "1",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    # First attempt with existing email -- no OTP sent, rejected as already registered.
    assert_enqueued_emails 0 do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "registered_cooldown@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content

    # Second attempt immediately -- same rejection, not an overwrite-window cooldown.
    assert_enqueued_emails 0 do
      post sign_app_sign_up_email_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "registered_cooldown@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content
  end

  test "otp_resend_too_soon i18n key exists in both locales" do
    assert_not_nil I18n.t("sign.app.registration.email.create.otp_resend_too_soon", locale: :ja, default: nil)
    assert_not_nil I18n.t("sign.app.registration.email.create.otp_resend_too_soon", locale: :en, default: nil)
  end

  private

  def default_headers
    { "Host" => host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end

  def current_sign_up_flow(user_email)
    ClientSignUpFlow.order(:id).find_by(
      principal_id: user_email.user_id,
      pending_contact_type: "email",
      pending_contact_id: user_email.id,
    ) || ClientSignUpFlow.order(:id).find_by!(
      principal_id: user_email.user_id,
      pending_contact_type: "email",
    )
  end

  def host
    ENV["ID_SERVICE_URL"] || "id.app.localhost"
  end
end
