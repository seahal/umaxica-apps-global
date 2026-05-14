# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :user_statuses, :user_token_statuses, :user_token_kinds, :user_email_statuses,
           :user_chronicle_events, :user_chronicle_levels

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    cookies["csrf_token"] = csrf_token_value
    @user = users(:one)
    @token = UserToken.create!(
      user: @user,
    )
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_email")

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id.to_s,
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  test "registration new is available" do
    get new_sign_app_configuration_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_select "input[name='cf-turnstile-response']", count: 1
    assert_includes response.body, "turnstile.execute"
    assert_includes response.body, "turbo:load"
    assert_includes response.body, "DOMContentLoaded"
    assert_select "a[href=?]", sign_app_configuration_emails_path(ri: "jp")
    assert_select "input[type=checkbox][name='user_email[promotional]']", count: 1
    assert_select "input[type=checkbox][name='user_email[notifiable]']", count: 1
  end

  test "registration new allows bootstrap when multi factor status is unconfigured" do
    user = User.create!(status_id: UserStatus::NOTHING)
    token = UserToken.create!(user_id: user.id)
    token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)
    headers = request_headers.merge(
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    Prosopite.pause do
      get new_sign_app_configuration_emails_registration_url(ri: "jp"), headers: headers
    end

    assert_response :success
    assert_equal UserMultiFactorStatus::UNCONFIGURED, user.reload.multi_factor_status_id
  end

  test "registration new requires step up when multi factor status is active" do
    user = User.create!(status_id: UserStatus::NOTHING)
    UserEmail.create!(
      user: user,
      address: "app-active-email-bootstrap@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    token = UserToken.create!(user_id: user.id)
    token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)
    headers = request_headers.merge(
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    Prosopite.pause do
      get new_sign_app_configuration_emails_registration_url(ri: "jp"), headers: headers
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_email", query["scope"]
    assert_equal UserMultiFactorStatus::ACTIVE, user.reload.multi_factor_status_id
  end

  test "registration edit renders stealth turnstile" do
    perform_enqueued_jobs do
      post sign_app_configuration_emails_registration_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "config-registration-edit@example.com",
             },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    get edit_sign_app_configuration_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, "turnstile.execute"
  end

  test "create sends OTP email" do
    assert_no_difference("User.count") do
      assert_enqueued_emails 1 do
        post sign_app_configuration_emails_registration_url(ri: "jp"),
             params: {
               user_email: {
                 raw_address: "config-registration@example.com",
               },
               "cf-turnstile-response": "test",
             },
             headers: request_headers
      end
    end

    assert_response :redirect
    assert_redirected_to edit_sign_app_configuration_emails_registration_url(ri: "jp")

    user_email = @user.user_emails.order(:created_at).last

    assert_equal UserEmailStatus::UNVERIFIED, user_email.user_email_status_id
  end

  test "create stores requested email preference flags" do
    post sign_app_configuration_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-registration-preferences@example.com",
             promotional: "0",
             notifiable: "0",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    assert_response :redirect

    user_email = @user.user_emails.order(:created_at).last

    assert_not user_email.promotional
    assert_not user_email.notifiable
  end

  test "update verifies OTP and confirms email" do
    perform_enqueued_jobs do
      post sign_app_configuration_emails_registration_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "config-verify@example.com",
             },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    user_email = @user.user_emails.order(:created_at).last

    assert_not_nil user_email
    otp_data = user_email.get_otp
    code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    assert_difference(
      -> {
        UserChronicle.where(
          actor_type: "User",
          actor_id: @user.id,
          subject_type: "User",
          subject_id: @user.id,
          event_id: UserChronicleEvent::EMAIL_REGISTERED,
        ).count
      },
      1,
    ) do
      patch sign_app_configuration_emails_registration_url(ri: "jp"),
            params: {
              user_email: {
                pass_code: code,
              },
            },
            headers: request_headers
    end

    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
    assert_equal UserEmailStatus::VERIFIED, user_email.reload.user_email_status_id
    assert_equal @user.id, user_email.user_id
    assert_not_nil @token.reload.last_step_up_at
    assert_equal "configuration_email", @token.last_step_up_scope
  end

  test "update rejects when turnstile fails" do
    perform_enqueued_jobs do
      post sign_app_configuration_emails_registration_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "config-turnstile-failure@example.com",
             },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    user_email = @user.user_emails.order(:created_at).last
    CloudflareTurnstile.test_validation_response = { "success" => false }

    patch sign_app_configuration_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: "123456",
            },
          },
          headers: request_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("turnstile_error")
    assert_equal UserEmailStatus::UNVERIFIED, user_email.reload.user_email_status_id
  end

  test "bootstrap email registration satisfies email configuration step-up" do
    bootstrap_user = users(:two)
    bootstrap_token = UserToken.create!(user: bootstrap_user)
    satisfy_user_verification(bootstrap_token)

    bootstrap_headers = request_headers.merge(
      "X-TEST-CURRENT-USER" => bootstrap_user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => bootstrap_token.public_id.to_s,
    )

    perform_enqueued_jobs do
      post sign_app_configuration_emails_registration_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "bootstrap-config-verify@example.com",
             },
             "cf-turnstile-response": "test",
           },
           headers: bootstrap_headers
    end

    user_email = bootstrap_user.user_emails.order(:created_at).last
    otp_data = user_email.get_otp
    code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_configuration_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: code,
            },
          },
          headers: bootstrap_headers

    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
    assert_equal "configuration_email", bootstrap_token.reload.last_step_up_scope

    get sign_app_configuration_emails_url(ri: "jp"), headers: bootstrap_headers

    assert_response :success
  end

  test "update returns to preserved rt after verifying OTP" do
    return_to = sign_app_configuration_emails_path(ri: "jp")
    rt = Base64.urlsafe_encode64(return_to)

    get new_sign_app_configuration_emails_registration_url(ri: "jp", rt: rt), headers: request_headers

    assert_response :success

    perform_enqueued_jobs do
      post sign_app_configuration_emails_registration_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "config-verify-rt@example.com",
             },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    assert_response :redirect
    assert_redirected_to edit_sign_app_configuration_emails_registration_url(ri: "jp", rt: rt)

    user_email = @user.user_emails.order(:created_at).last
    otp_data = user_email.get_otp
    code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_configuration_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: code,
            },
          },
          headers: request_headers

    assert_redirected_to return_to
    assert_equal UserEmailStatus::VERIFIED, user_email.reload.user_email_status_id
  end

  test "edit falls back to latest unverified email when session is missing" do
    post sign_app_configuration_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-session-recovery@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    session.delete(:email_registration_public_id)

    get edit_sign_app_configuration_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "edit renders OTP resend control" do
    rt = Base64.urlsafe_encode64(sign_app_configuration_challenge_path(ri: "jp"))

    post sign_app_configuration_emails_registration_url(ri: "jp", rt: rt),
         params: {
           user_email: {
             raw_address: "config-resend-control@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    get edit_sign_app_configuration_emails_registration_url(ri: "jp", rt: rt), headers: request_headers

    assert_response :success
    assert_select "form[action=?][method=?]",
                  resend_sign_app_configuration_emails_registration_path(ri: "jp", rt: rt),
                  "post"
    assert_select "button", text: I18n.t("otp.resend.button")
  end

  test "resend sends a new OTP after cooldown" do
    post sign_app_configuration_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-resend@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    user_email = @user.user_emails.order(:created_at).last
    original_counter = user_email.otp_counter

    travel Common::OtpPolicy::SEND_COOLDOWN + 1.second do
      assert_enqueued_emails 1 do
        post resend_sign_app_configuration_emails_registration_url(ri: "jp"), headers: request_headers
      end
    end

    assert_redirected_to edit_sign_app_configuration_emails_registration_url(ri: "jp")
    assert_equal I18n.t("otp.resend.sent"), flash[:notice]
    assert_not_equal original_counter, user_email.reload.otp_counter
  end

  test "resend is rate limited during cooldown" do
    post sign_app_configuration_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-resend-rate-limit@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    assert_enqueued_emails 0 do
      post resend_sign_app_configuration_emails_registration_url(ri: "jp"), headers: request_headers
    end

    assert_redirected_to edit_sign_app_configuration_emails_registration_url(ri: "jp")
    assert_equal I18n.t("otp.resend.too_soon"), flash[:alert]
  end

  test "update with blank pass_code renders edit with error" do
    post sign_app_configuration_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-blank-code@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    user_email = @user.user_emails.order(:created_at).last

    assert_not_nil user_email
    session[:email_registration_public_id] = user_email.public_id

    patch sign_app_configuration_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: "",
            },
          },
          headers: request_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.code_required")
  end

  test "update with wrong pass_code renders edit with error" do
    post sign_app_configuration_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-wrong-code@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    user_email = @user.user_emails.order(:created_at).last

    assert_not_nil user_email
    session[:email_registration_public_id] = user_email.public_id

    patch sign_app_configuration_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: "000000",
            },
          },
          headers: request_headers

    assert_response :unprocessable_content
  end

  test "edit with invalid session redirects to new registration" do
    get edit_sign_app_configuration_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :redirect
    assert_redirected_to new_sign_app_configuration_emails_registration_url(ri: "jp")
    assert_includes flash[:notice], I18n.t("sign.app.registration.email.edit.session_expired")
  end
end
