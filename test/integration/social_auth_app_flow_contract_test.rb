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
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
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

    assert_redirected_to sign_app_dashboard_url(ri: "jp")
    identity = config.fetch(:model).find_by!(uid: uid)
    user = identity.user

    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user.status_id
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

    assert_redirected_to sign_app_dashboard_url(ri: "jp")
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

    assert_redirected_to sign_app_configuration_url(ri: "jp")
    assert config.fetch(:model).exists?(identity.id)
    assert_predicate flash[:alert], :present?
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

    delete(
      sign_app_social_authentication_url(provider: config.fetch(:provider), ri: "jp"),
      headers: as_user_headers(user, host: @host, session_public_id: token.public_id),
    )
  end
end
