# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Sign::App::Configuration::TotpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients,
           :client_statuses,
           :client_token_statuses,
           :client_token_kinds,
           :client_totp_credential_statuses,
           :app_preference_chronicle_levels,
           :client_chronicle_events,
           :client_chronicle_levels

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    # Clear existing TOTPs to avoid limit error
    @user.client_totp_credentials.destroy_all
    ClientEmail.create!(
      user: @user,
      address: "totp-config-test@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    @token = ClientToken.create!(user_id: @user.id)
    @token.rotate_refresh_token!
    @token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "configuration_totp")
    access_token = Authentication::Base::Token.encode(
      @user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: @token.public_id,
    )
    @headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
    }.freeze
    cookies["csrf_token"] = "test_csrf_token"
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(@token)
    @headers.freeze

    @totp = ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      last_otp_at: Time.zone.at(0),
      title: "Main TOTP",
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  def with_prosopite_paused
    Prosopite.pause { yield }
  end

  test "should get index" do
    with_prosopite_paused do
      get sign_app_configuration_totps_url(ri: "jp"), headers: @headers
    end

    assert_response :success
  end

  test "index stays accessible when no totp is registered" do
    user = Client.create!(status_id: ClientStatus::NOTHING)
    token = ClientToken.create!(user_id: user.id)
    satisfy_user_verification(token)
    access_token = Authentication::Base::Token.encode(
      user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: token.public_id,
    )
    headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token

    with_prosopite_paused do
      get sign_app_configuration_totps_url(ri: "jp"), headers: headers
    end

    assert_response :success
    assert_select "a[href=?]", new_sign_app_configuration_totp_path(ri: "jp")
    assert_includes response.body, I18n.t("messages.no_totp_found")
  end

  test "index requires step up when multi factor status is active even without totp" do
    user = Client.create!(status_id: ClientStatus::NOTHING)
    ClientEmail.create!(
      user: user,
      address: "totp-active-with-email@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = ClientToken.create!(user_id: user.id)
    token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)
    access_token = Authentication::Base::Token.encode(
      user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: token.public_id,
    )
    headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token

    with_prosopite_paused do
      get sign_app_configuration_totps_url(ri: "jp"), headers: headers
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_totp", query["scope"]
    assert_equal ClientMfaStatus::ACTIVE, user.reload.mfa_status_id
  end

  test "should show up link on index page" do
    with_prosopite_paused do
      get sign_app_configuration_totps_url(ri: "jp"), headers: @headers
    end

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp")
  end

  test "should get new" do
    with_prosopite_paused do
      get new_sign_app_configuration_totp_url(ri: "jp"), headers: @headers
    end

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_totps_path(ri: "jp")
    assert_select "input[name='cf-turnstile-response']"
  end

  test "should get edit with public_id" do
    with_prosopite_paused do
      get edit_sign_app_configuration_totp_url(@totp.public_id, ri: "jp"), headers: @headers
    end

    assert_response :success
    assert_equal @totp.public_id, request.path_parameters[:id]
    assert_nil request.path_parameters[:public_id]
    assert_select "a[href=?]", sign_app_configuration_totps_path(ri: "jp")
  end

  test "should update title with public_id" do
    with_prosopite_paused do
      patch sign_app_configuration_totp_url(@totp.public_id, ri: "jp"),
            params: { user_totp_credential: { title: "Updated TOTP" } },
            headers: @headers
    end

    assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
    assert_equal "Updated TOTP", @totp.reload.title
  end

  test "should destroy with public_id" do
    assert_difference("ClientTotpCredential.count", -1) do
      with_prosopite_paused do
        delete sign_app_configuration_totp_url(@totp.public_id, ri: "jp"), headers: @headers
      end
    end

    assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
  end

  test "should return 404 for other user's totp" do
    other_user = clients(:two)
    other_totp = ClientTotpCredential.create!(
      user: other_user,
      private_key: ROTP::Base32.random_base32,
      last_otp_at: Time.zone.at(0),
      title: "Other TOTP",
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    with_prosopite_paused do
      get edit_sign_app_configuration_totp_url(other_totp.public_id, ri: "jp"), headers: @headers
    end

    assert_response :not_found
  end

  test "should create totp with valid token" do
    # Clear TOTP created in setup to allow creation of a new one (limit is 2)
    @user.client_totp_credentials.destroy_all

    with_mocked_totp do |secret_credential|
      with_prosopite_paused do
        get new_sign_app_configuration_totp_url(ri: "jp"), headers: @headers
      end

      assert_response :success
      assert_select "input[name='cf-turnstile-response']"
      token = ROTP::TOTP.new(secret_credential).now
      step_up_before = Time.current

      assert_difference("ClientTotpCredential.count") do
        assert_difference(
          -> {
            ClientChronicle.where(
              actor_type: "Client",
              actor_id: @user.id,
              subject_type: "Client",
              subject_id: @user.id,
              event_id: ClientChronicleEvent::TOTP_ENABLED,
            ).count
          },
          1,
        ) do
          with_prosopite_paused do
            post sign_app_configuration_totps_url(ri: "jp"),
                 params: { user_totp_credential: { first_token: token } },
                 headers: @headers
          end
        end
      end

      assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
      assert_operator @token.reload.last_step_up_at, :<, step_up_before
      assert_equal "configuration_totp", @token.last_step_up_scope
    end
  end

  test "should assign attributes to created totp" do
    @user.client_totp_credentials.destroy_all

    with_mocked_totp do |secret_credential|
      with_prosopite_paused do
        get new_sign_app_configuration_totp_url(ri: "jp"), headers: @headers
      end

      assert_response :success
      assert_select "input[name='cf-turnstile-response']"
      token = ROTP::TOTP.new(secret_credential).now

      with_prosopite_paused do
        post sign_app_configuration_totps_url(ri: "jp"),
             params: { user_totp_credential: { first_token: token, title: "New TOTP" } },
             headers: @headers
      end

      created_totp = ClientTotpCredential.order(created_at: :desc).first

      assert_equal "New TOTP", created_totp.title
      assert_not_nil created_totp.last_otp_at
    end
  end

  test "should not create totp with invalid token" do
    with_prosopite_paused do
      get new_sign_app_configuration_totp_url(ri: "jp"), headers: @headers
    end

    assert_response :success
    assert_select "input[name='cf-turnstile-response']"

    assert_no_difference("ClientTotpCredential.count") do
      with_prosopite_paused do
        post sign_app_configuration_totps_url(ri: "jp"),
             params: { user_totp_credential: { first_token: "000000" } },
             headers: @headers
      end
    end

    assert_response :unprocessable_content
  end

  test "should not create totp when turnstile stealth fails" do
    with_mocked_totp do |secret_credential|
      with_prosopite_paused do
        get new_sign_app_configuration_totp_url(ri: "jp"), headers: @headers
      end

      assert_response :success
      assert_select "input[name='cf-turnstile-response']"

      CloudflareTurnstile.test_validation_response = { "success" => false }
      token = ROTP::TOTP.new(secret_credential).now

      assert_no_difference("ClientTotpCredential.count") do
        with_prosopite_paused do
          post sign_app_configuration_totps_url(ri: "jp"),
               params: { user_totp_credential: { first_token: token, title: "Blocked TOTP" } },
               headers: @headers
        end
      end
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("turnstile_error")
  end

  test "initial setup user can access totp pages without step-up" do
    user = create_verified_user_with_email(email_address: "initial_totp_access@example.com")
    token = ClientToken.create!(user_id: user.id)
    token.rotate_refresh_token!
    token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "configuration_totp")
    satisfy_user_verification(token)
    access_token = Authentication::Base::Token.encode(
      user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: token.public_id,
    )
    headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(token)

    with_prosopite_paused do
      get sign_app_configuration_totps_url(ri: "jp"), headers: headers
    end

    assert_response :success
  end

  test "initial setup user can create first totp without step-up" do
    user = create_verified_user_with_email(email_address: "initial_totp_create@example.com")
    token = ClientToken.create!(user_id: user.id)
    token.rotate_refresh_token!
    token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "configuration_totp")
    satisfy_user_verification(token)
    access_token = Authentication::Base::Token.encode(
      user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: token.public_id,
    )
    headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(token)

    with_mocked_totp do |secret_credential|
      with_prosopite_paused do
        get new_sign_app_configuration_totp_url(ri: "jp"), headers: headers
      end

      assert_response :success
      first_code = ROTP::TOTP.new(secret_credential).now

      assert_difference("ClientTotpCredential.count", 1) do
        with_prosopite_paused do
          post sign_app_configuration_totps_url(ri: "jp"),
               params: { user_totp_credential: { first_token: first_code } },
               headers: headers
        end
      end
    end

    assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
  end

  private

  def with_mocked_totp
    known_secret_credential = "JBSWY3DPEHPK3PXP"
    ROTP::Base32.stub(:random_base32, known_secret_credential) do
      yield known_secret_credential
    end
  end
end
