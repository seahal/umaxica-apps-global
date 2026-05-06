# typed: false
# frozen_string_literal: true

require "test_helper"

class AppleSocialFlowsTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_social_apple_statuses, :app_preference_chronicle_levels

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @callback_headers = SocialCallbackTestHelper.callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "sign up creates user and identity" do
    setup_apple_mock_auth(uid: "apple_flow_signup")

    assert_difference("User.count", 1) do
      assert_difference("UserSocialApple.count", 1) do
        get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
            headers: @callback_headers
      end
    end

    assert_redirected_to sign_app_configuration_url(ri: "jp")
  end

  test "sign in uses existing identity" do
    user = User.create!(status_id: UserStatus::ACTIVE)
    UserSocialApple.create!(
      user: user,
      uid: "apple_flow_existing",
      provider: "apple",
      token: "token_old",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: user_social_apple_statuses(:active),
    )

    setup_apple_mock_auth(uid: "apple_flow_existing", token: "token_new")

    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: @callback_headers

    assert_redirected_to sign_app_configuration_url(ri: "jp")
    assert_equal I18n.t("sign.app.social.sessions.create.already_registered", provider: "Apple"),
                 flash[:notice]
  end

  test "link succeeds for logged in user" do
    user = users(:one)
    setup_apple_mock_auth(uid: "apple_flow_link")

    get sign_app_social_start_url(provider: "apple", intent: "link", ri: "jp"),
        headers: as_user_headers(user, host: @host)

    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(user, host: @host))

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:notice], :present?

    identity = UserSocialApple.find_by(uid: "apple_flow_link")

    assert_not_nil identity
    assert_equal user.id, identity.user_id
  end

  test "link succeeds even when auth headers are missing on callback" do
    user = users(:one)
    setup_apple_mock_auth(uid: "apple_flow_link_session_only")

    get sign_app_social_start_url(provider: "apple", intent: "link", ri: "jp"),
        headers: as_user_headers(user, host: @host)

    # Simulate Apple POST callback without auth cookies/headers
    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: @callback_headers

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:notice], :present?

    identity = UserSocialApple.find_by(uid: "apple_flow_link_session_only")

    assert_not_nil identity
    assert_equal user.id, identity.user_id
  end

  test "link conflict returns error" do
    owner = users(:one)
    other = users(:two)

    UserSocialApple.create!(
      user: owner,
      uid: "apple_flow_conflict",
      provider: "apple",
      token: "token_old",
      expires_at: 1.week.from_now.to_i,
      user_social_apple_status: user_social_apple_statuses(:active),
    )

    setup_apple_mock_auth(uid: "apple_flow_conflict")

    get sign_app_social_start_url(provider: "apple", intent: "link", ri: "jp"),
        headers: as_user_headers(other, host: @host)

    get sign_app_auth_callback_url(provider: "apple", ri: "jp"),
        headers: @callback_headers.merge(as_user_headers(other, host: @host))

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:alert], :present?

    identity = UserSocialApple.find_by(uid: "apple_flow_conflict")

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
end
