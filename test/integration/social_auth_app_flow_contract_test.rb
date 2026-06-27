# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthAppFlowContractTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_email_statuses, :client_totp_credential_statuses,
           :client_google_identity_statuses, :client_apple_identity_statuses

  PROVIDERS = {
    google: {
      provider: "google",
      normalized: "google",
      model: ClientGoogleIdentity,
      active_status: ClientGoogleIdentityStatus::ACTIVE,
      config_path: :auth_app_settings_path,
      token_prefix: "google",
    },
    apple: {
      provider: "apple",
      normalized: "apple",
      model: ClientAppleIdentity,
      active_status: ClientAppleIdentityStatus::ACTIVE,
      config_path: :auth_app_settings_apple_path,
      token_prefix: "apple",
    },
  }.freeze

  setup do
    OmniAuth.config.test_mode = true
    CloudflareTurnstile.test_mode = true
    JitSecurityTurnstileVerifier.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "log.umaxica.app")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @callback_headers = social_callback_headers(@host)
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
    JitSecurityTurnstileVerifier.test_mode = false
  end

  test "Google sign up entry creates one client and one active social identity without email" do
    assert_social_signup_contract(PROVIDERS.fetch(:google))
  end

  test "Apple sign up entry creates one client and one active social identity without email" do
    assert_social_signup_contract(PROVIDERS.fetch(:apple))
  end

  test "Google sign in reuses existing social identity and refreshes credentials" do
    assert_social_sign_in_contract(PROVIDERS.fetch(:google))
  end

  test "Apple sign in reuses existing social identity and refreshes credentials" do
    assert_social_sign_in_contract(PROVIDERS.fetch(:apple))
  end

  test "Google settings link creates identity for the signed-in client only" do
    assert_settings_link_contract(PROVIDERS.fetch(:google))
  end

  test "Apple settings link creates identity for the signed-in client only" do
    assert_settings_link_contract(PROVIDERS.fetch(:apple))
  end

  test "Google settings link rejects replacing an existing provider with a different uid" do
    assert_settings_replacement_rejected(PROVIDERS.fetch(:google))
  end

  test "Apple settings link rejects replacing an existing provider with a different uid" do
    assert_settings_replacement_rejected(PROVIDERS.fetch(:apple))
  end

  test "Google settings unlink succeeds when Apple remains available" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "unlink_google")
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "backup_apple")

    delete_with_verified_session(user, PROVIDERS.fetch(:google))

    assert_redirected_to auth_app_settings_google_url(ri: "jp", host: @host)
    assert_not PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
    assert PROVIDERS.fetch(:apple).fetch(:model).exists?(apple_identity.id)
  end

  test "Apple settings unlink succeeds when Google remains available" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "backup_google")
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "unlink_apple")

    delete_with_verified_session(user, PROVIDERS.fetch(:apple))

    assert_redirected_to auth_app_settings_apple_path(ri: "jp")
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
    assert_not PROVIDERS.fetch(:apple).fetch(:model).exists?(apple_identity.id)
  end

  test "Apple settings link succeeds again after unlink while Google remains available" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "relink_backup_google")
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "relink_old_apple")

    delete_with_verified_session(user, PROVIDERS.fetch(:apple))

    assert_redirected_to auth_app_settings_apple_path(ri: "jp")
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
    assert_not PROVIDERS.fetch(:apple).fetch(:model).exists?(apple_identity.id)

    new_uid = "relink_new_apple_#{SecureRandom.hex(4)}"
    grant_session = seed_app_social_link_grant_session(provider: "apple", user: user, ri: "jp")
    setup_mock_auth(PROVIDERS.fetch(:apple), uid: new_uid, token: "relinked_apple_token")

    # Settings link commits on Sign after the Sign-owned OAuth state and step-up checks.
    assert_no_difference("Client.count") do
      assert_difference("ClientAppleIdentity.count", 1) do
        perform_social_callback(
          PROVIDERS.fetch(:apple),
          params: { state: grant_session.state },
          headers: @callback_headers.merge(grant_session.user_headers),
        )
      end
    end

    assert_redirected_to auth_app_settings_path(ri: "jp")
    relinked_identity = ClientAppleIdentity.find_by!(uid: new_uid)

    assert_equal user.id, relinked_identity.user_id
    assert_equal ClientAppleIdentityStatus::ACTIVE, relinked_identity.status_id
    assert_equal "relinked_apple_token", relinked_identity.token
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
  end

  test "Google settings unlink keeps the last active login method" do
    assert_last_social_unlink_rejected(PROVIDERS.fetch(:google))
  end

  test "Apple settings unlink keeps the last active login method" do
    assert_last_social_unlink_rejected(PROVIDERS.fetch(:apple))
  end

  test "Google settings unlink redirects to verification without social unlink step-up" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "step_up_google")
    create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "step_up_backup_apple")
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    delete(
      settings_url_for(PROVIDERS.fetch(:google), ri: "jp", host: @host),
      headers: sign_user_headers(user, token),
      params: { "cf-turnstile-response": "test" },
    )

    assert_response :unauthorized
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
  end

  test "Google settings link rejects settings step-up scope" do
    user = create_social_client
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    post(
      settings_url_for(PROVIDERS.fetch(:google), ri: "jp"),
      headers: as_user_headers(user, host: @host, session_public_id: token.public_id),
    )

    assert_response :see_other
    assert_match %r{\Ahttp://#{Regexp.escape(@host)}/verification\?}, response.location
    assert_includes response.location, "scope=social_link"
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "Google settings unlink rejects passcode as the only remaining method" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "passcode_google")
    create_login_secret_credential(user)

    delete_with_verified_session(user, PROVIDERS.fetch(:google))

    assert_response :unprocessable_content
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
  end

  test "Google settings unlink rejects failed Turnstile before unlinking" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "turnstile_google")
    create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "turnstile_backup_apple")
    CloudflareTurnstile.test_validation_response = { "success" => false }

    delete_with_verified_session(user, PROVIDERS.fetch(:google))

    assert_response :see_other
    assert_redirected_to auth_app_settings_google_url(ri: "jp", host: @host)
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
  end

  private

  def assert_social_signup_contract(config)
    uid = "#{config.fetch(:normalized)}_signup_#{SecureRandom.hex(4)}"
    state = seed_social_auth_session(provider: config.fetch(:provider), intent: "login", entry: "sign_up", ri: "jp")
    setup_mock_auth(config, uid:, token: "new_signup_token")

    assert_no_difference("Client.count") do
      assert_no_difference("#{config.fetch(:model)}.count") do
        perform_social_callback(
          config,
          params: { state: state },
          headers: browser_headers.merge(@callback_headers),
        )
      end
    end

    assert_redirected_to public_send(:"auth_app_sign_up_guard_#{config.fetch(:normalized)}_url", ri: "jp")
    follow_redirect!

    assert_redirected_to public_send(:"auth_app_sign_up_check_#{config.fetch(:normalized)}_confirmation_url", ri: "jp")
    follow_redirect!

    assert_response :ok
    assert_select "input[name=confirm_new_social_identity]"
    assert_select "input[name=confirm_new_social_identity][required]"

    cycle = ClientSignUpFlow.order(:id).last

    patch(
      public_send(:"auth_app_sign_up_check_#{config.fetch(:normalized)}_confirmation_url", ri: "jp"),
      params: { confirm_new_social_identity: "1", checkpoint_version: cycle.checkpoint_version },
      headers: browser_headers.merge(@callback_headers),
    )

    assert_redirected_to public_send(:"auth_app_sign_up_check_#{config.fetch(:normalized)}_birthdate_url", ri: "jp")
    follow_redirect!

    assert_no_difference("Client.count") do
      assert_no_difference("#{config.fetch(:model)}.count") do
        patch(
          public_send(:"auth_app_sign_up_check_#{config.fetch(:normalized)}_birthdate_url", ri: "jp"),
          params: {
            requirement: "birthdate",
            birthdate: "2000-02-03",
            checkpoint_version: cycle.reload.checkpoint_version,
          },
          headers: browser_headers.merge(@callback_headers),
        )
      end
    end

    assert_response :ok
    assert_includes response.body, "social-completion-form"

    assert_difference("Client.count", 1) do
      assert_difference("#{config.fetch(:model)}.count", 1) do
        submit_social_completion_if_present!
      end
    end

    identity = config.fetch(:model).find_by!(uid: uid)
    user = identity.user

    assert_response :redirect
    assert_equal "2000-02-03", user.reload.birthdate
    assert ClientToken.exists?(user_id: user.id)

    assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, user.status_id
    assert_equal config.fetch(:active_status), identity.status_id
    assert_equal config.fetch(:provider), identity.provider
    assert_equal "new_signup_token", identity.token
    assert_not_nil identity.last_authenticated_at
    assert_nil ClientEmail.find_by(user: user)
  end

  def assert_social_sign_in_contract(config)
    uid = "#{config.fetch(:normalized)}_signin_#{SecureRandom.hex(4)}"
    user = create_social_client
    identity = create_social_identity(config, user:, uid:, token: "old_token")

    state = seed_social_auth_session(provider: config.fetch(:provider), intent: "login", ri: "jp")
    setup_mock_auth(config, uid:, token: "fresh_token")

    assert_no_difference("Client.count") do
      assert_no_difference("#{config.fetch(:model)}.count") do
        perform_social_callback(
          config,
          params: { state: state },
          headers: browser_headers.merge(@callback_headers),
        )
      end
    end

    assert_redirected_to base_app_dashboard_url(ri: "jp", host: @acme_host)
    identity.reload

    assert_equal user.id, identity.user_id
    assert_equal "fresh_token", identity.token
    assert_not_nil identity.last_authenticated_at
  end

  def assert_settings_link_contract(config)
    uid = "#{config.fetch(:normalized)}_link_#{SecureRandom.hex(4)}"
    user = create_social_client

    grant_session = seed_app_social_link_grant_session(provider: config.fetch(:provider), user: user, ri: "jp")
    setup_mock_auth(config, uid:, token: "linked_token")

    # The sign callback creates the social identity directly for settings link.
    assert_no_difference("Client.count") do
      assert_difference("#{config.fetch(:model)}.count", 1) do
        perform_social_callback(
          config,
          params: { state: grant_session.state },
          headers: @callback_headers.merge(grant_session.user_headers),
        )
      end
    end

    assert_redirected_to auth_app_settings_path(ri: "jp")
    identity = config.fetch(:model).find_by!(uid: uid)

    assert_equal user.id, identity.user_id
    assert_equal config.fetch(:active_status), identity.status_id
    assert_equal "linked_token", identity.token
    assert_not_nil identity.last_authenticated_at
  end

  def assert_settings_replacement_rejected(config)
    user = create_social_client
    existing = create_social_identity(config, user:, uid: "existing_#{config.fetch(:normalized)}", token: "keep_token")

    headers = as_user_headers(user, host: @host)
    token = ClientToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    mark_token_step_up_satisfied_for_test(token, scope: SocialAuth::SOCIAL_LINK_SCOPE)

    assert_no_difference("#{config.fetch(:model)}.count") do
      post(settings_url_for(config, ri: "jp"), headers: headers)
    end

    assert_response :unprocessable_content
    existing.reload

    assert_equal "existing_#{config.fetch(:normalized)}", existing.uid
    assert_equal "keep_token", existing.token
    assert_nil config.fetch(:model).find_by(uid: "different_#{config.fetch(:normalized)}")
  end

  def assert_last_social_unlink_rejected(config)
    user = create_social_client
    identity = create_social_identity(config, user:, uid: "last_#{config.fetch(:normalized)}")

    delete_with_verified_session(user, config)

    assert_response :unprocessable_content
    assert config.fetch(:model).exists?(identity.id)
  end

  def perform_social_callback(config, params:, headers:)
    if config.fetch(:provider) == "apple"
      post(auth_app_social_apple_callback_url(provider: "apple", ri: "jp"), params: params, headers: headers)
    else
      get(
        auth_app_social_google_callback_url(provider: config.fetch(:provider), ri: "jp"),
        params: params,
        headers: headers,
      )
    end
    submit_social_completion_if_present!
  end

  def setup_mock_auth(config, uid:, token:)
    normalized = config.fetch(:normalized)
    credentials = { token: token, expires_at: 1.week.from_now.to_i }
    credentials[:refresh_token] = "refresh_#{token}" if normalized == "google"

    extra = {}
    extra[:id_info] = { nonce: session[:social_auth_nonce] } if normalized == "apple"

    OmniAuth.config.mock_auth[normalized.to_sym] = OmniAuth::AuthHash.new(
      provider: normalized,
      uid: uid,
      info: {},
      credentials: credentials,
      extra: extra,
    )
  end

  def create_social_client
    user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "soc_#{SecureRandom.hex(6)}",
      birthdate: "2000-02-03",
      last_step_up_at: 1.minute.ago,
    )
    ClientEmail.create!(
      user: user,
      address: "social-contract-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )
    ClientTotpCredential.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
    user
  end

  def create_social_identity(config, user:, uid:, token: "token")
    config.fetch(:model).create!(
      user: user,
      uid: uid,
      provider: config.fetch(:provider),
      token: token,
      expires_at: 1.week.from_now.to_i,
      status_id: config.fetch(:active_status),
    )
  end

  def delete_with_verified_session(user, config)
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(token)
    mark_token_step_up_satisfied_for_test(token, scope: "social_unlink")

    delete(
      settings_url_for(config, ri: "jp", host: @host),
      headers: sign_user_headers(user, token),
      params: { "cf-turnstile-response": "test" },
    )
  end

  def settings_url_for(config, **params)
    public_send(:"auth_app_settings_#{config.fetch(:normalized)}_path", **params)
  end

  def sign_user_headers(user, token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def token_bound_step_up_for_social_link(user)
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: SocialAuth::SOCIAL_LINK_SCOPE)
    token
  end

  def create_login_secret_credential(user)
    ClientSecretCredentialKind.find_or_create_by!(id: ClientSecretCredentialKind::LOGIN)
    ClientSecretCredentialStatus.find_or_create_by!(id: ClientSecretCredentialStatus::ACTIVE)
    secret_credential = ClientSecretCredential.new(
      user: user,
      name: "passcode",
      password_digest: "digest",
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
      user_identity_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
    )
    secret_credential.save!(validate: false)
  end
end
