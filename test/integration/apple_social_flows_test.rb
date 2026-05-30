# typed: false
# frozen_string_literal: true

require "test_helper"

class AppleSocialFlowsTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_apple_identity_statuses, :app_preference_chronicle_levels

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
    @callback_headers = social_callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "sign up creates user and identity" do
    setup_apple_mock_auth(uid: "apple_flow_signup")

    state = start_social_auth_flow(intent: "login")

    assert_difference("Client.count", 1) do
      assert_difference("ClientAppleIdentity.count", 1) do
        post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
             params: { state: state },
             headers: @callback_headers
      end
    end

    assert_redirected_to sign_app_up_guardrail_url(ri: "jp")
  end

  test "sign in uses existing identity" do
    user = Client.create!(status_id: ClientStatus::ACTIVE)
    ClientAppleIdentity.create!(
      user: user,
      uid: "apple_flow_existing",
      provider: "apple",
      token: "token_old",
      token_expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    setup_apple_mock_auth(uid: "apple_flow_existing", token: "token_new")

    state = start_social_auth_flow(intent: "login")

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: @callback_headers

    assert_redirected_to sign_app_up_guardrail_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_up_checkpoint_url(ri: "jp")
    assert_equal "Appleで登録を開始しました", flash[:notice]
  end

  test "link succeeds for logged in user" do
    user = clients(:one)
    setup_apple_mock_auth(uid: "apple_flow_link")

    state = start_social_auth_flow(intent: "link", user: user)

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: @callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:notice], :present?

    identity = ClientAppleIdentity.find_by(uid: "apple_flow_link")

    assert_not_nil identity
    assert_equal user.id, identity.user_id
  end

  test "link succeeds even when auth headers are missing on callback" do
    user = clients(:one)
    setup_apple_mock_auth(uid: "apple_flow_link_session_only")

    state = start_social_auth_flow(intent: "link", user: user)

    # Simulate Apple POST callback without auth cookies/headers
    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: @callback_headers

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:notice], :present?

    identity = ClientAppleIdentity.find_by(uid: "apple_flow_link_session_only")

    assert_not_nil identity
    assert_equal user.id, identity.user_id
  end

  test "link conflict returns error" do
    owner = clients(:one)
    other = clients(:two)

    ClientAppleIdentity.create!(
      user: owner,
      uid: "apple_flow_conflict",
      provider: "apple",
      token: "token_old",
      token_expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    setup_apple_mock_auth(uid: "apple_flow_conflict")

    state = start_social_auth_flow(intent: "link", user: other)

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: @callback_headers.merge(as_user_headers(other, host: @host))

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:alert], :present?

    identity = ClientAppleIdentity.find_by(uid: "apple_flow_conflict")

    assert_equal owner.id, identity.user_id
  end

  private

  def setup_apple_mock_auth(uid:, token: "apple_token")
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {},
      credentials: {
        token: token,
        expires_at: 1.week.from_now.to_i,
      },
    )
  end

  def start_social_auth_flow(intent:, user: nil)
    seed_social_auth_session(provider: "apple", intent: intent, user: user, ri: "jp")
  end
end
