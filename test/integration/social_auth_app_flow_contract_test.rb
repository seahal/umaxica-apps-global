# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthAppFlowContractTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_social_google_statuses, :client_social_apple_statuses

  PROVIDERS = {
    google_app: {
      provider: "google_app",
      normalized: "google",
      model: ClientSocialGoogle,
      active_status: ClientSocialGoogleStatus::ACTIVE,
      config_path: :sign_app_configuration_path,
      token_prefix: "google",
    },
    apple: {
      provider: "apple",
      normalized: "apple",
      model: ClientSocialApple,
      active_status: ClientSocialAppleStatus::ACTIVE,
      config_path: :sign_app_configuration_apple_path,
      token_prefix: "apple",
    },
  }.freeze

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
    @callback_headers = social_callback_headers(@host)
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "Google sign up entry creates one client and one active social identity without email" do
    assert_social_signup_contract(PROVIDERS.fetch(:google_app))
  end

  test "Apple sign up entry creates one client and one active social identity without email" do
    assert_social_signup_contract(PROVIDERS.fetch(:apple))
  end

  test "Google sign in reuses existing social identity and refreshes credentials" do
    assert_social_sign_in_contract(PROVIDERS.fetch(:google_app))
  end

  test "Apple sign in reuses existing social identity and refreshes credentials" do
    assert_social_sign_in_contract(PROVIDERS.fetch(:apple))
  end

  test "Google configuration link creates identity for the signed-in client only" do
    assert_configuration_link_contract(PROVIDERS.fetch(:google_app))
  end

  test "Apple configuration link creates identity for the signed-in client only" do
    assert_configuration_link_contract(PROVIDERS.fetch(:apple))
  end

  test "Google configuration link rejects replacing an existing provider with a different uid" do
    assert_configuration_replacement_rejected(PROVIDERS.fetch(:google_app))
  end

  test "Apple configuration link rejects replacing an existing provider with a different uid" do
    assert_configuration_replacement_rejected(PROVIDERS.fetch(:apple))
  end

  test "Google configuration unlink succeeds when Apple remains available" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google_app), user:, uid: "unlink_google")
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "backup_apple")

    delete_with_verified_session(user, PROVIDERS.fetch(:google_app))

    assert_redirected_to sign_app_configuration_url(ri: "jp")
    assert_not PROVIDERS.fetch(:google_app).fetch(:model).exists?(google_identity.id)
    assert PROVIDERS.fetch(:apple).fetch(:model).exists?(apple_identity.id)
  end

  test "Apple configuration unlink succeeds when Google remains available" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google_app), user:, uid: "backup_google")
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "unlink_apple")

    delete_with_verified_session(user, PROVIDERS.fetch(:apple))

    assert_redirected_to sign_app_configuration_url(ri: "jp")
    assert PROVIDERS.fetch(:google_app).fetch(:model).exists?(google_identity.id)
    assert_not PROVIDERS.fetch(:apple).fetch(:model).exists?(apple_identity.id)
  end

  test "Google configuration unlink keeps the last active login method" do
    assert_last_social_unlink_rejected(PROVIDERS.fetch(:google_app))
  end

  test "Apple configuration unlink keeps the last active login method" do
    assert_last_social_unlink_rejected(PROVIDERS.fetch(:apple))
  end

  test "Google configuration unlink redirects to verification without social unlink step-up" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google_app), user:, uid: "step_up_google")
    create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "step_up_backup_apple")
    token = ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    delete(
      sign_app_social_authentication_url(provider: "google_app", ri: "jp"),
      headers: as_user_headers(user, host: @host, session_public_id: token.public_id),
      params: { "cf-turnstile-response": "test" },
    )

    assert_response :see_other
    assert_match %r{/verification}, response.location
    assert PROVIDERS.fetch(:google_app).fetch(:model).exists?(google_identity.id)
  end

  test "Google configuration unlink rejects passcode as the only remaining method" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google_app), user:, uid: "passcode_google")
    create_login_secret(user)

    delete_with_verified_session(user, PROVIDERS.fetch(:google_app))

    assert_response :unprocessable_content
    assert PROVIDERS.fetch(:google_app).fetch(:model).exists?(google_identity.id)
    assert_includes response.body, I18n.t("errors.social_auth.insufficient_login_methods")
  end

  test "Google configuration unlink rejects failed Turnstile before unlinking" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google_app), user:, uid: "turnstile_google")
    create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "turnstile_backup_apple")
    CloudflareTurnstile.test_validation_response = { "success" => false }

    delete_with_verified_session(user, PROVIDERS.fetch(:google_app))

    assert_response :see_other
    assert_redirected_to sign_app_configuration_google_url(ri: "jp")
    assert PROVIDERS.fetch(:google_app).fetch(:model).exists?(google_identity.id)
  end

  private

  def assert_social_signup_contract(config)
    uid = "#{config.fetch(:normalized)}_signup_#{SecureRandom.hex(4)}"
    setup_mock_auth(config, uid:, token: "new_signup_token")
    state = seed_social_auth_session(provider: config.fetch(:provider), intent: "login", entry: "sign_up", ri: "jp")

    assert_difference("Client.count", 1) do
      assert_difference("#{config.fetch(:model)}.count", 1) do
        perform_social_callback(
          config,
          params: { state: state },
          headers: browser_headers.merge(@callback_headers),
        )
      end
    end

    identity = config.fetch(:model).find_by!(uid: uid)
    user = identity.user

    assert_redirected_to sign_app_up_guardrail_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_up_checkpoint_url(ri: "jp")
    follow_redirect!

    assert_response :ok
    assert_select "input[type=date][name=birthdate]"

    cycle = ClientSignUpCycle.find_by!(principal_id: user.id)
    patch(
      sign_app_up_checkpoint_birthdate_url(ri: "jp"),
      params: {
        requirement: "birthdate",
        birthdate: "2000-02-03",
        checkpoint_version: cycle.checkpoint_version,
      },
      headers: browser_headers.merge(@callback_headers),
    )

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

    setup_mock_auth(config, uid:, token: "fresh_token")
    state = seed_social_auth_session(provider: config.fetch(:provider), intent: "login", ri: "jp")

    assert_no_difference("Client.count") do
      assert_no_difference("#{config.fetch(:model)}.count") do
        perform_social_callback(
          config,
          params: { state: state },
          headers: browser_headers.merge(@callback_headers),
        )
      end
    end

    assert_redirected_to sign_app_in_checkpoint_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_welcome_entry_url(ri: "jp")
    identity.reload

    assert_equal user.id, identity.user_id
    assert_equal "fresh_token", identity.token
    assert_not_nil identity.last_authenticated_at
  end

  def assert_configuration_link_contract(config)
    uid = "#{config.fetch(:normalized)}_link_#{SecureRandom.hex(4)}"
    user = create_social_client

    setup_mock_auth(config, uid:, token: "linked_token")
    state = seed_social_auth_session(provider: config.fetch(:provider), intent: "link", user: user, ri: "jp")

    assert_no_difference("Client.count") do
      assert_difference("#{config.fetch(:model)}.count", 1) do
        perform_social_callback(
          config,
          params: { state: state },
          headers: @callback_headers.merge(as_user_headers(user, host: @host)),
        )
      end
    end

    assert_redirected_to sign_app_configuration_url(ri: "jp")
    identity = config.fetch(:model).find_by!(uid: uid)

    assert_equal user.id, identity.user_id
    assert_equal config.fetch(:active_status), identity.status_id
    assert_equal "linked_token", identity.token
    assert_not_nil identity.last_authenticated_at
  end

  def assert_configuration_replacement_rejected(config)
    user = create_social_client
    existing = create_social_identity(config, user:, uid: "existing_#{config.fetch(:normalized)}", token: "keep_token")

    setup_mock_auth(config, uid: "different_#{config.fetch(:normalized)}", token: "wrong_token")
    state = seed_social_auth_session(provider: config.fetch(:provider), intent: "link", user: user, ri: "jp")

    assert_no_difference("#{config.fetch(:model)}.count") do
      perform_social_callback(
        config,
        params: { state: state },
        headers: @callback_headers.merge(as_user_headers(user, host: @host)),
      )
    end

    assert_redirected_to public_send(config.fetch(:config_path), ri: "jp")
    existing.reload

    assert_equal "existing_#{config.fetch(:normalized)}", existing.uid
    assert_equal "keep_token", existing.token
    assert_predicate flash[:alert], :present?
    assert_nil config.fetch(:model).find_by(uid: "different_#{config.fetch(:normalized)}")
  end

  def assert_last_social_unlink_rejected(config)
    user = create_social_client
    identity = create_social_identity(config, user:, uid: "last_#{config.fetch(:normalized)}")

    delete_with_verified_session(user, config)

    assert_response :unprocessable_content
    assert config.fetch(:model).exists?(identity.id)
    assert_includes response.body, I18n.t("errors.social_auth.insufficient_login_methods")
  end

  def perform_social_callback(config, params:, headers:)
    if config.fetch(:provider) == "apple"
      post(sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"), params: params, headers: headers)
    else
      get(sign_app_auth_callback_url(provider: config.fetch(:provider), ri: "jp"), params: params, headers: headers)
    end
  end

  def setup_mock_auth(config, uid:, token:)
    credentials = {
      token: token,
      expires_at: 1.week.from_now.to_i,
    }
    credentials[:refresh_token] = "refresh_#{token}" if config.fetch(:provider) == "google_app"

    OmniAuth.config.mock_auth[config.fetch(:provider).to_sym] = OmniAuth::AuthHash.new(
      provider: config.fetch(:provider),
      uid: uid,
      info: {},
      credentials: credentials,
    )
  end

  def create_social_client
    Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "soc_#{SecureRandom.hex(6)}",
      birthdate: "2000-02-03",
      last_step_up_at: 1.minute.ago,
    )
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
      sign_app_social_authentication_url(provider: config.fetch(:provider), ri: "jp"),
      headers: as_user_headers(user, host: @host, session_public_id: token.public_id),
      params: { "cf-turnstile-response": "test" },
    )
  end

  def create_login_secret(user)
    ClientSecretKind.find_or_create_by!(id: ClientSecretKind::LOGIN)
    ClientSecretStatus.find_or_create_by!(id: ClientSecretStatus::ACTIVE)
    secret = ClientSecret.new(
      user: user,
      name: "passcode",
      password_digest: "digest",
      user_secret_kind_id: ClientSecretKind::LOGIN,
      user_identity_secret_status_id: ClientSecretStatus::ACTIVE,
    )
    secret.save!(validate: false)
  end
end
