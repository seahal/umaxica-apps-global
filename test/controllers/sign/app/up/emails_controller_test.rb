# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Up::EmailsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
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
  end

  test "renders email registration form structure" do
    get new_sign_app_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success

    assert_select "h2", I18n.t("sign.app.registration.email.new.page_title")
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

    # Second registration attempt after cooldown expires (case-variant)
    # This should delete the previous unverified record and create a new one
    travel Common::OtpPolicy::SEND_COOLDOWN + 1.second do
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
    assert_match(%r{/up/emails/[^/]+/edit}, path)
  end

  test "create with existing email still redirects and does not create a new record" do
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

    assert_response :redirect
    assert_includes response.location, "/sign/up/emails/#{existing_email.public_id}/edit"
    assert_equal I18n.t("sign.app.registration.email.create.verification_code_sent"), flash[:notice]
    assert_nil flash[:alert]
  end

  test "create shows identical user-facing response for existing and new emails" do
    existing_user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
    UserEmail.create!(
      user: existing_user,
      address: "enum-safe@example.com",
      confirm_policy: "1",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    post sign_app_up_emails_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "enum-safe@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    existing_location = response.location
    existing_notice = flash[:notice]

    post sign_app_up_emails_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "brand-new@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect
    assert_match(%r{/up/emails/[^/]+/edit}, response.location)
    assert_equal existing_notice, flash[:notice]
    assert_match(%r{/up/emails/[^/]+/edit}, existing_location)
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

  test "create with existing email enqueues no emails" do
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

    assert_response :redirect
    assert_match(%r{/up/emails/[^/]+/edit}, response.location)
    assert_equal before_otp_last_sent_at, existing_email.reload.otp_last_sent_at
    assert_equal before_otp_counter, existing_email.otp_counter
    assert_equal before_otp_attempts_count, existing_email.otp_attempts_count
  end

  test "update for existing registered email redirects to sign-in without otp verification" do
    user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
    existing_email = UserEmail.create!(
      user: user,
      address: "existing_update_redirect@example.com",
      confirm_policy: "1",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    post sign_app_up_emails_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: existing_email.address,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect
    assert_match(%r{/up/emails/[^/]+/edit}, response.location)

    patch sign_app_up_email_url(existing_email, ri: "jp"),
          params: {
            id: existing_email.id,
            user_email: {
              pass_code: "123456",
            },
          },
          headers: default_headers

    assert_response :redirect
    assert_redirected_to %r{/in/new}
    assert_equal I18n.t("sign.app.registration.email.update.sign_in_required"), flash[:notice]
  end

  test "update for existing registered email with OTP required" do
    user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
    existing_email = UserEmail.create!(
      user: user,
      address: "existing_otp_required@example.com",
      confirm_policy: "1",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    post sign_app_up_emails_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: existing_email.address,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect
    assert_match(%r{/up/emails/[^/]+/edit}, response.location)

    patch sign_app_up_email_url(existing_email, ri: "jp"),
          params: {
            id: existing_email.id,
            user_email: {
              pass_code: "123456",
            },
          },
          headers: default_headers

    assert_response :redirect
    assert_redirected_to new_sign_app_in_path(ri: "jp")
    assert_equal I18n.t("sign.app.registration.email.update.sign_in_required"), flash[:notice]
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
    assert_includes @response.body, "ボット検証に失敗しました"
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

    # Make 3 failed attempts
    3.times do
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

  test "redirects to root when user is already logged in" do
    # Create a user and log them in
    user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)

    # Try to access registration page while logged in (using test header to inject current user)
    get new_sign_app_up_email_url(ri: "jp"),
        headers: default_headers.merge({ "X-TEST-CURRENT-USER" => user.id })

    assert_redirected_to "/configuration?ri=jp"
    assert_equal I18n.t("sign.app.registration.email.already_logged_in"), flash[:alert]
  end

  test "redirects to encoded URL after successful registration when rd parameter is provided" do
    email = "redirect_test@example.com"
    redirect_url = "/dashboard"
    encoded_rd = Base64.urlsafe_encode64(redirect_url)

    # Create registration record with rd parameter
    post sign_app_up_emails_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
           rd: encoded_rd,
         },
         headers: default_headers

    # Verify rd parameter is preserved in redirect
    assert_response :redirect
    assert_includes response.location, "rd=#{CGI.escape(encoded_rd)}"

    # Extract email ID from redirect location
    assert_response :redirect, "Expected redirect but got #{response.status}: #{response.body[0..500]}"
    email_id = response.location.match(/\/up\/emails\/([^\/\?]+)/)[1]
    user_email = UserEmail.find_by(public_id: email_id)

    otp_data = user_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
    correct_code = hotp.at(otp_data[:otp_counter]).to_s

    # Submit correct OTP with rd parameter
    patch sign_app_up_email_url(user_email, ri: "jp"),
          params: {
            id: user_email.id,
            user_email: {
              pass_code: correct_code,
            },
            rd: encoded_rd,
          },
          headers: default_headers

    # Should redirect directly to the decoded rd destination
    assert_redirected_to redirect_url
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
    assert_redirected_to sign_app_configuration_path(ri: "jp")

    # Verify User count unchanged (pending user was updated, not created)
    assert_equal initial_user_count, User.count

    # Verify UserEmail was updated and linked to user
    user_email.reload

    assert_not_nil user_email.user_id
    assert_equal UserEmailStatus::VERIFIED_WITH_SIGN_UP, user_email.user_email_status_id

    # Verify User has correct status
    user = user_email.user

    assert_equal UserStatus::VERIFIED_WITH_SIGN_UP, user.status_id
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
    assert_redirected_to sign_app_configuration_path(ri: "jp")

    # Verify UserChronicle was created
    assert_equal initial_audit_count + 1, UserChronicle.count
    audit = UserChronicle.last
    user = user_email.reload.user

    assert_equal user.id.to_s, audit.user_id
    assert_equal user.id, audit.actor_id
    assert_equal "User", audit.actor_type
    assert_equal UserChronicleEvent::SIGNED_UP_WITH_EMAIL, audit.event_id
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
    email_id = response.location.match(%r{/up/emails/([^/?]+)})[1]
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

    assert_redirected_to sign_app_configuration_path(ri: "jp")
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

    email_id = response.location.match(%r{/up/emails/([^/?]+)})[1]
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
  test "create returns 429 when resending OTP within cooldown for new signup" do
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

    # Second attempt immediately (within 30s cooldown)
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

  test "create allows resending OTP after cooldown expires for new signup" do
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

    # After cooldown expires
    travel Common::OtpPolicy::SEND_COOLDOWN + 1.second do
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

  test "cooldown does not apply to existing registered emails" do
    user = User.create!(status_id: UserStatus::VERIFIED_WITH_SIGN_UP)
    UserEmail.create!(
      user: user,
      address: "registered_cooldown@example.com",
      confirm_policy: "1",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    # First attempt with existing email -- no OTP sent, still redirects
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

    assert_response :redirect

    # Second attempt immediately -- same behavior, no 429
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

    assert_response :redirect
  end

  test "otp_resend_too_soon i18n key exists in both locales" do
    assert_not_nil I18n.t("sign.app.registration.email.create.otp_resend_too_soon", locale: :ja, default: nil)
    assert_not_nil I18n.t("sign.app.registration.email.create.otp_resend_too_soon", locale: :en, default: nil)
  end

  private

  def default_headers
    { "Host" => host, "HTTPS" => "on" }
  end

  def host
    ENV["ID_SERVICE_URL"] || "id.app.localhost"
  end
end
