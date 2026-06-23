# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Sign::App::Settings::TotpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients,
           :client_statuses,
           :client_token_statuses,
           :client_token_kinds,
           :client_secret_credential_kinds,
           :client_secret_credential_statuses,
           :client_totp_credential_statuses,
           :app_preference_chronicle_levels,
           :client_chronicle_events,
           :client_chronicle_levels

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    # Clear existing TOTPs to avoid limit error
    @user.client_totp_credentials.destroy_all
    @user.client_secret_credentials.destroy_all
    create_client_recovery_passcode!(@user, name: "recovery 1")
    create_client_recovery_passcode!(@user, name: "recovery 2")
    ClientEmail.create!(
      user: @user,
      address: "totp-config-test@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    @token = ClientToken.create!(user_id: @user.id)
    @token.rotate_refresh_token!
    @token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "settings_totp")
    access_token = AuthenticationToken.encode(
      @user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: @token.public_id,
    )
    @headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
    cookies["csrf_token"] = "test_csrf_token"
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
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
    IdentityTotpCeremonyCandidate.find_each(&:destroy!)
  end

  def with_prosopite_paused
    Prosopite.pause { yield }
  end

  test "should get index" do
    with_prosopite_paused do
      get sign_app_settings_totps_url(ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_select "table"
  end

  test "index stays accessible when no totp is registered" do
    user = Client.create!(status_id: ClientStatus::NOTHING)
    token = ClientToken.create!(user_id: user.id)
    satisfy_user_verification(token)
    access_token = AuthenticationToken.encode(
      user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: token.public_id,
    )
    headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    with_prosopite_paused do
      get sign_app_settings_totps_url(ri: "jp"), headers: headers
    end

    assert_response :ok
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
    access_token = AuthenticationToken.encode(
      user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: token.public_id,
    )
    headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    with_prosopite_paused do
      get sign_app_settings_totps_url(ri: "jp"), headers: headers
    end

    assert_response :ok
    assert_equal ClientMfaStatus::ACTIVE, user.reload.mfa_status_id
  end

  test "should show up link on index page" do
    with_prosopite_paused do
      get sign_app_settings_totps_url(ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_select "a[href=?]", new_sign_app_settings_totp_path(ri: "jp")
  end

  test "should get new" do
    with_prosopite_paused do
      get new_sign_app_settings_totp_url(ri: "jp", totp_ceremony_grant: totp_ceremony_grant), headers: @headers
    end

    assert_response :success
    assert_select "a[href=?]", sign_app_settings_totps_path(ri: "jp")
    assert_select "form[action=?]", sign_app_settings_totps_path(ri: "jp")
    assert_select "input[name='user_totp_credential[title]']"
    assert_select "input[name='user_totp_credential[first_token]'][pattern]", count: 0
    assert_select "label", text: I18n.t("views.sign.app.settings.totps.new.first_token_label")
    assert_select "input[placeholder=?]", I18n.t("views.sign.app.settings.totps.new.first_token_placeholder")
    assert_select "input[type=submit][value=?]", I18n.t("views.sign.app.settings.totps.new.submit")
    assert_includes response.body, "認証アプリ"
    assert_includes response.body, I18n.t("views.sign.app.settings.totps.new.first_token_delivery_help")
    assert_not_includes response.body, "届きます"
    assert_not_includes response.body, "送信され"
    assert_select "input[name='cf-turnstile-response']"
  end

  test "new denies with zero unused usable recovery passcodes" do
    @user.client_secret_credentials.destroy_all

    get new_sign_app_settings_totp_url(ri: "jp", totp_ceremony_grant: totp_ceremony_grant), headers: @headers

    assert_response :forbidden
    assert_equal "text/html", response.media_type
    assert_includes response.body, sign_app_settings_secret_credentials_url(
      ri: "jp",
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
    )
    assert_empty flash.to_hash
  end

  test "create denies with one unused usable recovery passcode and does not return json" do
    @user.client_totp_credentials.destroy_all
    @user.client_secret_credentials.destroy_all
    create_client_recovery_passcode!(@user, name: "only recovery")

    assert_no_difference("ClientTotpCredential.count") do
      post sign_app_settings_totps_url(ri: "jp"),
           params: {
             totp_ceremony_grant: totp_ceremony_grant,
             user_totp_credential: { first_token: "000000" },
           },
           headers: @headers,
           as: :json
    end

    assert_response :forbidden
    assert_equal "text/html", response.media_type
    assert_empty flash.to_hash
  end

  test "used and revoked recovery passcodes are not counted" do
    @user.client_secret_credentials.destroy_all
    create_client_recovery_passcode!(@user, name: "used", last_used_at: Time.current)
    create_client_recovery_passcode!(
      @user,
      name: "revoked",
      status_id: ClientSecretCredentialStatus::REVOKED,
    )

    get new_sign_app_settings_totp_url(ri: "jp", totp_ceremony_grant: totp_ceremony_grant), headers: @headers

    assert_response :forbidden
  end

  test "should get edit with public_id" do
    with_prosopite_paused do
      get edit_sign_app_settings_totp_url(@totp.public_id, ri: "jp"), headers: @headers
    end

    assert_response :ok
    assert_select "form[action=?]", sign_app_settings_totp_path(@totp.public_id, ri: "jp")
    assert_equal @totp.public_id, request.path_parameters[:id]
    assert_nil request.path_parameters[:public_id]
  end

  test "should update title with public_id" do
    with_prosopite_paused do
      patch sign_app_settings_totp_url(@totp.public_id, ri: "jp"),
            params: { user_totp_credential: { title: "Updated TOTP" } },
            headers: @headers
    end

    assert_redirected_to sign_app_settings_totp_path(@totp.public_id, ri: "jp")
    assert_equal "Updated TOTP", @totp.reload.title
  end

  test "should destroy with public_id" do
    assert_difference("ClientTotpCredential.count", -1) do
      with_prosopite_paused do
        delete sign_app_settings_totp_url(@totp.public_id, ri: "jp"), headers: @headers
      end
    end

    assert_redirected_to sign_app_settings_totps_path(ri: "jp")
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
      get edit_sign_app_settings_totp_url(other_totp.public_id, ri: "jp"), headers: @headers
    end

    assert_response :not_found
  end

  test "should create totp with valid token" do
    # Clear TOTP created in setup to allow creation of a new one (limit is 2)
    @user.client_totp_credentials.destroy_all

    with_mocked_totp do |secret_credential|
      grant = totp_ceremony_grant

      with_prosopite_paused do
        get new_sign_app_settings_totp_url(ri: "jp", totp_ceremony_grant: grant), headers: @headers
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
            post sign_app_settings_totps_url(ri: "jp"),
                 params: { totp_ceremony_grant: grant, user_totp_credential: { first_token: token } },
                 headers: @headers
          end
        end
      end

      assert_redirected_to sign_app_settings_totps_url(
        ri: "jp",
        host: ENV.fetch(
          "ID_SERVICE_URL", "id.app.localhost",
        ),
      )
      assert_operator @token.reload.last_step_up_at, :<, step_up_before
      assert_equal "settings_totp", @token.last_step_up_scope
    end
  end

  test "should assign attributes to created totp" do
    @user.client_totp_credentials.destroy_all

    with_mocked_totp do |secret_credential|
      grant = totp_ceremony_grant

      with_prosopite_paused do
        get new_sign_app_settings_totp_url(ri: "jp", totp_ceremony_grant: grant), headers: @headers
      end

      assert_response :success
      assert_select "input[name='cf-turnstile-response']"
      token = ROTP::TOTP.new(secret_credential).now

      with_prosopite_paused do
        post sign_app_settings_totps_url(ri: "jp"),
             params: {
               totp_ceremony_grant: grant,
               user_totp_credential: { first_token: token, title: "New TOTP" },
             },
             headers: @headers
      end

      created_totp = ClientTotpCredential.order(created_at: :desc).first

      assert_equal "New TOTP", created_totp.title
      assert_not_nil created_totp.last_otp_at
    end
  end

  test "should create totp with pasted token containing spaces" do
    @user.client_totp_credentials.destroy_all

    with_mocked_totp do |secret_credential|
      grant = totp_ceremony_grant

      with_prosopite_paused do
        get new_sign_app_settings_totp_url(ri: "jp", totp_ceremony_grant: grant), headers: @headers
      end

      raw_token = ROTP::TOTP.new(secret_credential).now
      pasted_token = "#{raw_token.first(3)} #{raw_token.last(3)}"

      assert_difference("ClientTotpCredential.count", 1) do
        with_prosopite_paused do
          post sign_app_settings_totps_url(ri: "jp"),
               params: {
                 totp_ceremony_grant: grant,
                 user_totp_credential: { first_token: pasted_token, title: "Pasted TOTP" },
               },
               headers: @headers
        end
      end
    end

    assert_redirected_to sign_app_settings_totps_url(ri: "jp", host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))
  end

  test "should not create totp with invalid token" do
    grant = totp_ceremony_grant

    with_prosopite_paused do
      get new_sign_app_settings_totp_url(ri: "jp", totp_ceremony_grant: grant), headers: @headers
    end

    assert_response :success
    assert_select "input[name='cf-turnstile-response']"

    assert_no_difference("ClientTotpCredential.count") do
      with_prosopite_paused do
        post sign_app_settings_totps_url(ri: "jp"),
             params: { totp_ceremony_grant: grant, user_totp_credential: { first_token: "000000" } },
             headers: @headers
      end
    end

    assert_response :unprocessable_content
  end

  test "should not create totp with empty token" do
    grant = totp_ceremony_grant

    with_prosopite_paused do
      get new_sign_app_settings_totp_url(ri: "jp", totp_ceremony_grant: grant), headers: @headers
    end

    assert_response :success

    assert_no_difference("ClientTotpCredential.count") do
      with_prosopite_paused do
        post sign_app_settings_totps_url(ri: "jp"),
             params: { totp_ceremony_grant: grant, user_totp_credential: { first_token: "", title: "" } },
             headers: @headers
      end
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.settings.totps.invalid_code")
  end

  test "should not create totp when turnstile stealth fails" do
    with_mocked_totp do |secret_credential|
      grant = totp_ceremony_grant

      with_prosopite_paused do
        get new_sign_app_settings_totp_url(ri: "jp", totp_ceremony_grant: grant), headers: @headers
      end

      assert_response :success
      assert_select "input[name='cf-turnstile-response']"

      CloudflareTurnstile.test_validation_response = { "success" => false }
      token = ROTP::TOTP.new(secret_credential).now

      assert_no_difference("ClientTotpCredential.count") do
        with_prosopite_paused do
          post sign_app_settings_totps_url(ri: "jp"),
               params: {
                 totp_ceremony_grant: grant,
                 user_totp_credential: { first_token: token, title: "Blocked TOTP" },
               },
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
    token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "settings_totp")
    satisfy_user_verification(token)
    access_token = AuthenticationToken.encode(
      user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: token.public_id,
    )
    headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(token)

    with_prosopite_paused do
      get sign_app_settings_totps_url(ri: "jp"), headers: headers
    end

    assert_response :ok
  end

  test "initial setup user can create first totp without step-up" do
    user = create_verified_user_with_email(email_address: "initial_totp_create@example.com")
    create_client_recovery_passcode!(user, name: "initial 1")
    create_client_recovery_passcode!(user, name: "initial 2")
    token = ClientToken.create!(user_id: user.id)
    token.rotate_refresh_token!
    token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "settings_totp")
    satisfy_user_verification(token)
    access_token = AuthenticationToken.encode(
      user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: token.public_id,
    )
    headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(token)

    with_mocked_totp do |secret_credential|
      grant = totp_ceremony_grant(actor: user, token: token)

      with_prosopite_paused do
        get new_sign_app_settings_totp_url(
          ri: "jp",
          totp_ceremony_grant: grant,
        ), headers: headers
      end

      assert_response :success
      first_code = ROTP::TOTP.new(secret_credential).now

      assert_difference("ClientTotpCredential.count", 1) do
        with_prosopite_paused do
          post sign_app_settings_totps_url(ri: "jp"),
               params: { totp_ceremony_grant: grant, user_totp_credential: { first_token: first_code } },
               headers: headers
        end
      end
    end

    assert_redirected_to sign_app_settings_totps_url(ri: "jp", host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))
  end

  private

  private

  def totp_ceremony_grant(actor: @user, token: @token)
    signed_totp_ceremony_grant_for(actor: actor, token: token)
  end

  def with_mocked_totp
    known_secret_credential = "JBSWY3DPEHPK3PXP"
    ROTP::Base32.stub(:random_base32, known_secret_credential) do
      yield known_secret_credential
    end
  end

  def create_client_recovery_passcode!(
    user,
    name:,
    status_id: ClientSecretCredentialStatus::ACTIVE,
    last_used_at: nil
  )
    credential = user.client_secret_credentials.new(
      name: name,
      user_secret_kind_id: ClientSecretCredentialKind::RECOVERY,
      user_identity_secret_status_id: status_id,
      last_used_at: last_used_at,
    )
    credential.password = ClientSecretCredential.generate_raw_secret_credential
    credential.save!(validate: false)
    credential
  end
end
