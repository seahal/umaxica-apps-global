# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Up::EmailsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    cookies["csrf_token"] = csrf_token_value
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get new" do
    get new_sign_app_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "div[id^='cf-turnstile-']", count: 1
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, "turnstile.render"
    assert_includes response.body, "turbo:load"
    assert_includes response.body, "DOMContentLoaded"
    assert_includes response.body, "callback: function(token)"
    assert_nil response.headers["Content-Security-Policy"]
  end

  test "collection get redirects to new email registration" do
    get sign_app_up_emails_url(ri: "jp", hotwire_spark: true, reload: "123"), headers: default_headers

    assert_response :redirect
    assert_includes response.location, "/sign/up/emails/new?ri=jp"
    assert_not_includes response.location, "hotwire_spark"
    assert_not_includes response.location, "reload"
  end

  test "renders email registration form structure" do
    get new_sign_app_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    assert_select "h2", I18n.t("sign.app.registration.email.new.page_title")
    assert_select "input[type=checkbox][name='user_email[promotional]']", count: 1
    assert_select "input[type=checkbox][name='user_email[notifiable]']", count: 1
    assert_no_match(/UMAXICA \(sign, app\)/, response.body)
  end

  test "includes navigation links to other registration flows" do
    get new_sign_app_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    assert_select "a[href=?]", new_sign_app_up_path(ri: "jp"), count: 1
    assert_select "a[href=?]", new_sign_app_in_email_path(ri: "jp"), count: 1
  end

  test "edit redirects to new when email record not found" do
    # Establish flow state by starting a registration
    post sign_app_up_emails_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "flow_setup@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    # Now we are in STATE_EMAIL_CREATED, so we can access edit
    # Try to access edit with non-existent ID
    get edit_sign_app_up_email_url(id: "non-existent-id", ri: "jp"), headers: default_headers

    assert_response :redirect
    assert_includes response.location, "/sign/up/emails/new"
    assert_not_includes response.location, "notice="
    assert_equal I18n.t("sign.app.registration.email.edit.not_found"), flash[:notice]
    assert_includes response.location, "ri=jp"
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
    post sign_app_up_emails_url(ri: "jp"),
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
    first_email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    first_email = UserEmail.find_by(public_id: first_email_id)

    assert_not_nil first_email
    assert_equal UserEmailStatus::UNVERIFIED_WITH_SIGN_UP, first_email.user_email_status_id

    assert_not_nil first_email.address_digest

    # Second registration attempt after the independent overwrite window expires (case-variant)
    # This should delete the previous unverified record and create a new one
    travel Common::OtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
      post sign_app_up_emails_url(ri: "jp"),
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
      new_email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]

      assert_not_equal first_email.id, new_email_id # Check IDs from URL differ
    end
  end

  test "create redirects to edit and allows edit page" do
    email = "flow_step_test@example.com"

    post sign_app_up_emails_url(ri: "jp"),
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
    assert_match(%r{/sign/up/emails/[^/]+/edit}, path)
  end

  test "create renders unprocessable when user_email param missing" do
    assert_no_difference("UserEmail.count") do
      post sign_app_up_emails_url(ri: "jp"),
           params: { "cf-turnstile-response": "test" },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.create.address_required")
  end

  test "create renders unprocessable when turnstile fails" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    assert_no_difference("UserEmail.count") do
      post sign_app_up_emails_url(ri: "jp"),
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
    user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
    existing_email = UserEmail.create!(
      user: user,
      address: "existing_signup@example.com",
      confirm_policy: "1",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    assert_no_difference("User.count") do
      assert_no_difference("UserEmail.count") do
        assert_enqueued_emails 0 do
          post sign_app_up_emails_url(ri: "jp"),
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
    assert_includes response.body, UserEmail.human_attribute_name(:address)
    assert_nil session[Sign::EmailRegistrable::EXISTING_EMAIL_SESSION_KEY]
  end

  test "create with existing verified-with-sign-up email is rejected" do
    existing_user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
    UserEmail.create!(
      user: existing_user,
      address: "completed-signup@example.com",
      confirm_policy: "1",
      user_email_status_id: UserEmailStatus::VERIFIED_WITH_SIGN_UP,
    )

    assert_no_difference("User.count") do
      assert_no_difference("UserEmail.count") do
        assert_enqueued_emails 0 do
          post sign_app_up_emails_url(ri: "jp"),
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
    assert_nil session[Sign::EmailRegistrable::EXISTING_EMAIL_SESSION_KEY]
  end

  test "create enqueues exactly one email" do
    email = "enqueue_test@example.com"

    assert_enqueued_emails 1 do
      post sign_app_up_emails_url(ri: "jp"),
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
    post sign_app_up_emails_url(ri: "jp"),
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

    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by!(public_id: email_id)

    assert_not user_email.promotional
    assert_not user_email.notifiable
  end

  test "create with existing verified email enqueues no emails and leaves otp state unchanged" do
    user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
    existing_email = UserEmail.create!(
      user: user,
      address: "no_otp_send@example.com",
      confirm_policy: "1",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    before_otp_last_sent_at = existing_email.otp_last_sent_at
    before_otp_counter = existing_email.otp_counter
    before_otp_attempts_count = existing_email.otp_attempts_count

    assert_enqueued_emails 0 do
      post sign_app_up_emails_url(ri: "jp"),
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
      post sign_app_up_emails_url(ri: "jp"),
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
        post sign_app_up_emails_url(ri: "jp"),
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
    assert_includes @response.body, UserEmail.human_attribute_name(:confirm_policy)
    assert_not_includes @response.body, "prohibited this sample from being saved"
    assert_no_match(/policy_missing@example\.com/, logs.join("\n"))
  end

  test "create with turnstile failure enqueues no emails and returns 422" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    email = "turnstile_fail@example.com"

    assert_enqueued_emails 0 do
      post(
        sign_app_up_emails_url(ri: "jp"),
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
      post sign_app_up_emails_url(ri: "jp"),
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
    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)

    # Attempt wrong code
    patch sign_app_up_email_url(user_email, ri: "jp"),
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
      post sign_app_up_emails_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)

    # Attempt with blank code
    patch sign_app_up_email_url(user_email, ri: "jp"),
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
      post sign_app_up_emails_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)

    # Travel to expire OTP
    travel 16.minutes do
      patch sign_app_up_email_url(user_email, ri: "jp"),
            params: {
              id: user_email.id,
              user_email: {
                pass_code: "123456",
              },
            },
            headers: default_headers

      assert_response :redirect
      assert_includes response.location, "/sign/up/emails/new"
      assert_equal I18n.t("sign.app.registration.email.edit.session_expired"), flash[:notice]
    end
  end

  test "deletes email record after max OTP attempts" do
    email = "test_max_attempts@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_up_emails_url(ri: "jp"),
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
    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)

    Email::MAX_OTP_ATTEMPTS.times do
      patch sign_app_up_email_url(user_email, ri: "jp"),
            params: {
              id: user_email.id,
              user_email: {
                pass_code: "000000",
              },
            },
            headers: default_headers
    end

    # Verify redirect and record deletion
    assert_response :redirect
    assert_includes response.location, "/sign/up/emails/new"
    assert_not_includes response.location, "alert="
    assert_equal I18n.t("sign.app.registration.email.update.attempts_exceeded"), flash[:alert]
    assert_includes response.location, "ri=jp"
    assert_equal I18n.t("sign.app.registration.email.update.attempts_exceeded"), flash[:alert]
    assert_includes response.location, "ri=jp"
    assert_nil UserEmail.find_by(public_id: user_email.public_id)
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
    get new_sign_app_up_email_url(ri: "jp"), headers: default_headers

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

  test "new redirects to dashboard when user is already logged in" do
    # Create a user and log them in
    user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)

    # Try to access registration page while logged in (using test header to inject current user)
    get new_sign_app_up_email_url(ri: "jp"),
        headers: as_user_headers(user, host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))

    assert_redirected_to sign_app_dashboard_url(ri: "jp")
  end

  test "create rejects when user is already logged in" do
    user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)

    assert_no_difference("UserEmail.count") do
      post sign_app_up_emails_url(ri: "jp"),
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
    assert_equal I18n.t("errors.messages.not_authorized"), response.body
  end

  test "redirects to encoded URL after successful registration when rt parameter is provided" do
    email = "redirect_test@example.com"
    redirect_url = "/dashboard"
    encoded_rt = Base64.urlsafe_encode64(redirect_url)

    # Create registration record with rt parameter
    post sign_app_up_emails_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
           rt: encoded_rt,
         },
         headers: default_headers

    # Verify rt parameter is preserved in redirect
    assert_response :redirect
    assert_includes response.location, "rt=#{CGI.escape(encoded_rt)}"

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)

    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    # Submit correct OTP with rt parameter
    patch sign_app_up_email_url(user_email, ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
            rt: encoded_rt,
          },
          headers: default_headers

    # Should redirect directly to the decoded rt destination
    assert_redirected_to sign_app_dashboard_path(ri: "jp", rt: encoded_rt)
  end

  # Transaction Tests for User Creation

  test "successful OTP verification creates user and saves email in transaction" do
    email = "transaction_success@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_up_emails_url(ri: "jp"),
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
    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    initial_user_count = User.count

    # Submit correct OTP
    patch sign_app_up_email_url(user_email, ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    # Verify success response
    assert_redirected_to sign_app_dashboard_path(ri: "jp")

    # Verify User count unchanged (pending user was updated, not created)
    assert_equal initial_user_count, User.count

    # Verify UserEmail was updated and linked to user
    user_email.reload

    assert_not_nil user_email.user_id
    assert_equal UserEmailStatus::VERIFIED_WITH_SIGN_UP, user_email.user_email_status_id

    # Verify User has correct status
    user = user_email.user

    assert_equal UserStatus::VERIFIED_WITH_SIGN_UP, user.status_id
    assert_predicate user.user_account, :present?
    assert_equal ResidentRecord.connection_db_config.name, user.user_account.class.connection_db_config.name
  end

  test "successful OTP verification creates audit log in transaction" do
    email = "audit_log_test@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_up_emails_url(ri: "jp"),
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
    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    initial_audit_count = UserChronicle.count

    # Submit correct OTP
    patch sign_app_up_email_url(user_email, ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    # Verify success response
    assert_redirected_to sign_app_dashboard_path(ri: "jp")

    # Verify UserChronicle was created
    user = user_email.reload.user

    assert_equal initial_audit_count + 2, UserChronicle.count
    assert_equal 1,
                 UserChronicle.where(
                   event_id: UserChronicleEvent::SIGNED_UP_WITH_EMAIL,
                   subject_id: user.id.to_s,
                   subject_type: "User",
                 ).count
    assert_equal 1,
                 UserChronicle.where(
                   event_id: UserChronicleEvent::LOGGED_IN,
                   subject_id: user.id.to_s,
                   subject_type: "User",
                 ).count
    assert_equal "email",
                 UserChronicle.where(
                   event_id: UserChronicleEvent::LOGGED_IN,
                   subject_id: user.id.to_s,
                   subject_type: "User",
                 ).last.context["auth_method"]

    get sign_app_configuration_activities_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.configuration.activity.events.signed_up_with_email")
    assert_includes response.body, I18n.t("sign.app.configuration.activity.events.logged_in")
  end

  test "successful OTP verification recreates missing signup audit event" do
    email = "missing_audit_event_signup@example.com"

    UserChronicle.where(event_id: UserChronicleEvent::SIGNED_UP_WITH_EMAIL).delete_all
    UserChronicleEvent.where(id: UserChronicleEvent::SIGNED_UP_WITH_EMAIL).delete_all

    post sign_app_up_emails_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = response.location.match(%r{/sign/up/emails/([^/?]+)})[1]
    user_email = UserEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    patch sign_app_up_email_url(user_email, ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    assert_redirected_to sign_app_dashboard_path(ri: "jp")
    assert UserChronicleEvent.exists?(id: UserChronicleEvent::SIGNED_UP_WITH_EMAIL)
    assert UserChronicle.exists?(
      event_id: UserChronicleEvent::SIGNED_UP_WITH_EMAIL,
      subject_id: user_email.user_id,
    )
  end

  test "sets user session after successful registration" do
    email = "session_set@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_up_emails_url(ri: "jp"),
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
    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    # Submit correct OTP
    patch sign_app_up_email_url(user_email, ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    # Verify JWT access token cookie was set
    assert_not_nil cookies[::Authentication::User::ACCESS_COOKIE_KEY],
                   "Access token cookie should be set after successful registration"

    # Verify user and token were created
    user = user_email.reload.user

    assert_not_nil user, "User should be created"
    assert UserToken.exists?(user_id: user.id), "User token should be created"
  end

  test "successful registration sets auth cookies with app-localhost domain" do
    email = "cookie_domain_up_#{SecureRandom.hex(4)}@example.com"

    post sign_app_up_emails_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    email_id = response.location.match(%r{/sign/up/emails/([^/?]+)})[1]
    user_email = UserEmail.find_by!(public_id: email_id)
    otp_data = user_email.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_up_email_url(user_email, ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: pass_code,
            },
          },
          headers: default_headers

    set_cookie = response.headers["Set-Cookie"].to_s

    assert_match(/domain=\.app\.localhost/i, set_cookie)
    assert_no_match(/domain=\.localhost/i, set_cookie)
  end

  test "OTP data is cleared after successful verification" do
    email = "otp_clear@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_up_emails_url(ri: "jp"),
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
    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    # Verify OTP data exists before verification
    assert_not_nil user_email.get_otp

    # Submit correct OTP
    patch sign_app_up_email_url(user_email, ri: "jp"),
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

  test "resets session ID after successful registration" do
    email = "session_reset_test@example.com"

    # Create registration record
    perform_enqueued_jobs do
      post sign_app_up_emails_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: email,
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)
    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    # Ensure we have a session
    get new_sign_app_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    old_session_id = session.id

    # Submit correct OTP
    patch sign_app_up_email_url(user_email.id, ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
          },
          headers: default_headers

    assert_not_nil session.id
    assert_not_equal old_session_id, session.id
  end

  test "creates pending user with UNVERIFIED_WITH_SIGN_UP status during email registration" do
    email = "pending_user_test@example.com"

    initial_user_count = User.count

    # Create registration record
    post sign_app_up_emails_url(ri: "jp"),
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
    assert_equal initial_user_count + 1, User.count

    # Extract email and verify it's linked to a pending user
    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)

    assert_not_nil user_email.user
    assert_equal UserStatus::UNVERIFIED_WITH_SIGN_UP, user_email.user.status_id
    assert_equal UserEmailStatus::UNVERIFIED_WITH_SIGN_UP, user_email.user_email_status_id
  end

  test "does not leave zero or null user_id in database" do
    email = "no_zero_user_id@example.com"

    # Create registration record
    post sign_app_up_emails_url(ri: "jp"),
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
    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)

    # Verify user_id is not zero or null
    assert_not_nil user_email.user_id, "user_id should not be nil"
    assert_not_equal "00000000-0000-0000-0000-000000000000", user_email.user_id,
                     "user_id should not be zero UUID"

    # Verify user actually exists
    assert User.exists?(id: user_email.user_id), "User record should exist for user_id"
  end

  test "deletes pending user when unverified email is replaced" do
    email = "replace_pending_test@example.com"

    # First registration attempt
    post sign_app_up_emails_url(ri: "jp"),
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
    first_email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    first_email = UserEmail.find_by(public_id: first_email_id)
    first_user_id = first_email.user_id

    # Count users before second attempt
    user_count_before_second = User.count

    # Second registration attempt after cooldown (should delete first pending user)
    travel Common::OtpPolicy::SEND_COOLDOWN + 1.second do
      post sign_app_up_emails_url(ri: "jp"),
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
      assert_nil User.find_by(id: first_user_id), "First pending user should be deleted"

      # Verify new user was created (count should remain the same: one deleted, one created)
      assert_equal user_count_before_second, User.count

      # Verify new email has a different user
      second_email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
      second_email = UserEmail.find_by(public_id: second_email_id)

      assert_not_equal first_user_id, second_email.user_id
      assert_not_nil second_email.user
    end
  end

  test "can abandon first email and register with a different email without error" do
    first_email = "first_abandoned@example.com"
    second_email = "second_attempt@example.com"

    # First registration attempt with email A
    post sign_app_up_emails_url(ri: "jp"),
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
    first_email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    first_record = UserEmail.find_by(public_id: first_email_id)
    first_user_id = first_record.user_id

    assert_not_nil first_record
    assert_equal UserEmailStatus::UNVERIFIED_WITH_SIGN_UP, first_record.user_email_status_id

    # User abandons: navigates back to "new" page
    # This should succeed without redirect loop or error
    get new_sign_app_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    # User submits a different email B
    post sign_app_up_emails_url(ri: "jp"),
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
    second_email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    second_record = UserEmail.find_by(public_id: second_email_id)

    assert_not_nil second_record
    assert_equal UserEmailStatus::UNVERIFIED_WITH_SIGN_UP, second_record.user_email_status_id
    assert_not_equal first_user_id, second_record.user_id

    # Verify first pending user was cleaned up
    assert_nil User.find_by(id: first_user_id),
               "First pending user should be cleaned up when registering with a different email"
  end

  # OTP Resend Cooldown Tests
  test "create returns 429 when re-registering inside overwrite window for new signup" do
    email = "cooldown_test@example.com"

    # First registration attempt
    assert_enqueued_emails 1 do
      post sign_app_up_emails_url(ri: "jp"),
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
      post sign_app_up_emails_url(ri: "jp"),
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
      post sign_app_up_emails_url(ri: "jp"),
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
    travel Common::OtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
      assert_enqueued_emails 1 do
        post sign_app_up_emails_url(ri: "jp"),
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
    user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
    UserEmail.create!(
      user: user,
      address: "registered_cooldown@example.com",
      confirm_policy: "1",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    # First attempt with existing email -- no OTP sent, rejected as already registered.
    assert_enqueued_emails 0 do
      post sign_app_up_emails_url(ri: "jp"),
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
      post sign_app_up_emails_url(ri: "jp"),
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

  def host
    ENV["ID_SERVICE_URL"] || "id.app.localhost"
  end
end
