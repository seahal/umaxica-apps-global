# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses, :client_token_statuses, :client_token_kinds, :client_email_statuses,
           :client_chronicle_events, :client_chronicle_levels

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    cookies["csrf_token"] = csrf_token_value
    @user = clients(:one)
    @token = ClientToken.create!(
      user: @user,
    )
    satisfy_user_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_email")

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
    get new_sign_app_settings_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_select "input[name='cf-turnstile-response']", count: 1
    assert_includes response.body, 'data-turnstile-mode-value="execute"'
    assert_select "a[href=?]", "https://#{ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")}/preference?ri=jp"
    assert_select "input[type=checkbox][name='user_email[promotional]']", count: 1
    assert_select "input[type=checkbox][name='user_email[notifiable]']", count: 1
  end

  test "registration new allows bootstrap when multi factor status is unconfigured" do
    user = Client.create!(status_id: ClientStatus::NOTHING)
    token = ClientToken.create!(user_id: user.id)
    token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)
    request_headers.merge!(
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    Prosopite.pause do
      get new_sign_app_settings_emails_registration_url(ri: "jp"),
          headers: request_headers.merge(
            "X-TEST-CURRENT-USER" => user.id.to_s,
            "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
          )
    end

    assert_response :success
    assert_equal ClientMfaStatus::UNCONFIGURED, user.reload.mfa_status_id
  end

  test "registration new requires step up when multi factor status is active" do
    user = Client.create!(status_id: ClientStatus::NOTHING)
    ClientEmail.create!(
      user: user,
      address: "app-active-email-bootstrap@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = ClientToken.create!(user_id: user.id)
    token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)
    headers = request_headers.merge(
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    Prosopite.pause do
      get new_sign_app_settings_emails_registration_url(ri: "jp"), headers: headers
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "settings_email", query["scope"]
    assert_equal ClientMfaStatus::ACTIVE, user.reload.mfa_status_id
  end

  test "registration edit renders stealth turnstile" do
    perform_enqueued_jobs do
      post sign_app_settings_emails_registration_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "config-registration-edit@example.com",
             },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    get edit_sign_app_settings_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, 'data-turnstile-mode-value="execute"'
    assert_select "h1", text: I18n.t("sign.app.authentication.email.edit.page_title")
    assert_select "label", text: I18n.t("sign.app.authentication.email.edit.code_label")
    assert_select "input[placeholder=?]", I18n.t("sign.app.authentication.email.edit.code_placeholder")
    assert_select "input[type=submit][value=?]", I18n.t("sign.app.authentication.email.edit.submit")
    assert_includes response.body, "メールアドレス"
    assert_includes response.body, I18n.t("sign.app.authentication.email.edit.delivery_help")
  end

  test "create accepts browser submitted client email params without pass code validation" do
    assert_enqueued_emails 1 do
      post sign_app_settings_emails_registration_url(ri: "jp"),
           params: {
             client_email: {
               address: "config-browser-scope@example.com",
               promotional: "0",
               notifiable: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    assert_response :redirect
    assert_redirected_to edit_sign_app_settings_emails_registration_url(ri: "jp")

    user_email = @user.client_emails.order(:created_at).last

    assert_equal "config-browser-scope@example.com", user_email.address
    assert_equal ClientEmailStatus::UNVERIFIED, user_email.user_email_status_id
    assert_empty user_email.errors[:pass_code]
  end

  test "create sends OTP email" do
    assert_no_difference("Client.count") do
      assert_enqueued_emails 1 do
        post sign_app_settings_emails_registration_url(ri: "jp"),
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
    assert_redirected_to edit_sign_app_settings_emails_registration_url(ri: "jp")

    user_email = @user.client_emails.order(:created_at).last

    assert_equal ClientEmailStatus::UNVERIFIED, user_email.user_email_status_id
  end

  test "create stores requested email preference flags" do
    post sign_app_settings_emails_registration_url(ri: "jp"),
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

    user_email = @user.client_emails.order(:created_at).last

    assert_not user_email.promotional
    assert_not user_email.notifiable
  end

  test "update verifies OTP and confirms email" do
    perform_enqueued_jobs do
      post sign_app_settings_emails_registration_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "config-verify@example.com",
             },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    user_email = @user.client_emails.order(:created_at).last

    assert_not_nil user_email
    otp_data = user_email.get_otp
    code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_settings_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: code,
            },
          },
          headers: request_headers

    assert_redirected_to "https://#{ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")}/preference?ri=jp"
    assert_equal ClientEmailStatus::VERIFIED, user_email.reload.user_email_status_id
    assert_equal @user.id, user_email.user_id
    assert_not_nil @token.reload.last_step_up_at
    assert_equal "settings_email", @token.last_step_up_scope
  end

  test "update rejects when turnstile fails" do
    perform_enqueued_jobs do
      post sign_app_settings_emails_registration_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "config-turnstile-failure@example.com",
             },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    user_email = @user.client_emails.order(:created_at).last
    CloudflareTurnstile.test_validation_response = { "success" => false }

    patch sign_app_settings_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: "123456",
            },
          },
          headers: request_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("turnstile_error")
    assert_equal ClientEmailStatus::UNVERIFIED, user_email.reload.user_email_status_id
  end

  test "bootstrap email registration satisfies email settings step-up" do
    bootstrap_user = clients(:two)
    bootstrap_token = ClientToken.create!(user: bootstrap_user)
    satisfy_user_verification(bootstrap_token)
    bootstrap_token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_email")

    bootstrap_headers = request_headers.merge(
      "X-TEST-CURRENT-USER" => bootstrap_user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => bootstrap_token.public_id.to_s,
    )

    perform_enqueued_jobs do
      post sign_app_settings_emails_registration_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "bootstrap-config-verify@example.com",
             },
             "cf-turnstile-response": "test",
           },
           headers: bootstrap_headers
    end

    user_email = bootstrap_user.client_emails.order(:created_at).last
    otp_data = user_email.get_otp
    code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_settings_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: code,
            },
          },
          headers: bootstrap_headers

    acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")

    assert_redirected_to "https://#{acme_host}/preference?ri=jp"
    assert_equal "settings_email", bootstrap_token.reload.last_step_up_scope

    get "https://#{acme_host}/preference?ri=jp",
        headers: bootstrap_headers.merge("Host" => acme_host)

    assert_response :success
  end

  test "update returns to acme email management after verifying OTP" do
    return_to = "https://#{ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")}/preference?ri=jp"
    pt = Base64.urlsafe_encode64(return_to)

    get new_sign_app_settings_emails_registration_url(ri: "jp", pt: pt), headers: request_headers

    assert_response :success

    perform_enqueued_jobs do
      post sign_app_settings_emails_registration_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "config-verify-pt@example.com",
             },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    assert_response :redirect
    assert_redirected_to edit_sign_app_settings_emails_registration_url(ri: "jp")

    user_email = @user.client_emails.order(:created_at).last
    otp_data = user_email.get_otp
    code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_settings_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: code,
            },
          },
          headers: request_headers

    assert_redirected_to "https://#{ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")}/preference?ri=jp"
    assert_equal ClientEmailStatus::VERIFIED, user_email.reload.user_email_status_id
  end

  test "edit falls back to latest unverified email when session is missing" do
    post sign_app_settings_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-session-recovery@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    session.delete(:email_registration_public_id)

    get edit_sign_app_settings_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "edit renders OTP resend control" do
    pt = Base64.urlsafe_encode64(sign_app_settings_mfa_challenge_path(ri: "jp"))
    post sign_app_settings_emails_registration_url(ri: "jp", pt: pt),
         params: {
           user_email: {
             raw_address: "config-resend-control@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    get edit_sign_app_settings_emails_registration_url(ri: "jp", pt: pt), headers: request_headers

    assert_response :success
    assert_select "form[action^='#{sign_app_settings_emails_registration_redelivery_path(ri: "jp")}'][method='post']"
    assert_select "button", text: I18n.t("otp.resend.button")
  end

  test "resend sends a new OTP after cooldown" do
    post sign_app_settings_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-resend@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    user_email = @user.client_emails.order(:created_at).last
    original_counter = user_email.otp_counter

    travel CommonOtpPolicy::SEND_COOLDOWN + 1.second do
      assert_enqueued_emails 1 do
        post sign_app_settings_emails_registration_redelivery_url(ri: "jp"), headers: request_headers
      end
    end

    assert_redirected_to edit_sign_app_settings_emails_registration_url(ri: "jp")
    assert_equal I18n.t("otp.resend.sent"), flash[:notice]
    assert_not_equal original_counter, user_email.reload.otp_counter
  end

  test "resend is rate limited during cooldown" do
    post sign_app_settings_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-resend-rate-limit@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    assert_enqueued_emails 0 do
      post sign_app_settings_emails_registration_redelivery_url(ri: "jp"), headers: request_headers
    end

    assert_redirected_to edit_sign_app_settings_emails_registration_url(ri: "jp")
    assert_equal I18n.t("otp.resend.too_soon"), flash[:alert]
  end

  test "update with blank pass_code renders edit with error" do
    post sign_app_settings_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-blank-code@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    user_email = @user.client_emails.order(:created_at).last

    assert_not_nil user_email
    session[:email_registration_public_id] = user_email.public_id

    patch sign_app_settings_emails_registration_url(ri: "jp"),
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
    post sign_app_settings_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-wrong-code@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    user_email = @user.client_emails.order(:created_at).last

    assert_not_nil user_email
    session[:email_registration_public_id] = user_email.public_id

    patch sign_app_settings_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: "000000",
            },
          },
          headers: request_headers

    assert_response :unprocessable_content
  end

  test "edit with invalid session redirects to new registration" do
    get edit_sign_app_settings_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :redirect
    assert_redirected_to new_sign_app_settings_emails_registration_url(ri: "jp")
    assert_includes flash[:notice], I18n.t("sign.app.registration.email.edit.session_expired")
  end

  private
end
