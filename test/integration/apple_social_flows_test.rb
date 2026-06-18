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

  test "sign up waits for confirmation before creating user and identity" do
    setup_apple_mock_auth(uid: "apple_flow_signup")

    state = start_social_auth_flow(intent: "login")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
             params: { state: state },
             headers: @callback_headers
      end
    end

    assert_redirected_to sign_app_sign_up_guard_apple_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_sign_up_check_apple_confirmation_url(ri: "jp")
    follow_redirect!

    assert_response :ok
    assert_select "input[name=confirm_new_social_identity][required]"

    cycle = ClientSignUpFlow.order(:id).last
    patch sign_app_sign_up_check_apple_confirmation_url(ri: "jp"),
          params: { confirm_new_social_identity: "1", checkpoint_version: cycle.checkpoint_version },
          headers: @callback_headers

    assert_redirected_to sign_app_sign_up_check_apple_birthdate_url(ri: "jp")

    assert_difference("Client.count", 1) do
      assert_difference("ClientAppleIdentity.count", 1) do
        patch sign_app_sign_up_check_apple_birthdate_url(ri: "jp"),
              params: {
                requirement: "birthdate",
                birthdate: "2000-02-03",
                checkpoint_version: cycle.reload.checkpoint_version,
              },
              headers: @callback_headers
      end
    end
  end

  test "cancel after unknown Apple callback creates nothing durable" do
    setup_apple_mock_auth(uid: "apple_flow_cancel")

    state = start_social_auth_flow(intent: "login")

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: @callback_headers

    assert_redirected_to sign_app_sign_up_guard_apple_url(ri: "jp")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        post sign_app_sign_up_check_apple_cancellation_url(ri: "jp"), headers: @callback_headers
      end
    end

    assert_redirected_to sign_app_sign_up_url(ri: "jp")
    assert_nil ClientAppleIdentity.find_by(uid: "apple_flow_cancel")
  end

  test "sign in uses existing identity" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    user.create_rp_account!
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

    submit_social_completion_if_present!

    assert_redirected_to acme_app_dashboard_url(
                           ri: "jp",
                           host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
                         )
  end

  test "settings link succeeds for logged in user via Sign callback" do
    user = clients(:one)
    setup_apple_mock_auth(uid: "apple_flow_link")

    grant_session = seed_app_social_link_grant_session(provider: "apple", user: user, ri: "jp")

    assert_difference("ClientAppleIdentity.count", 1) do
      post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
           params: { state: grant_session.state },
           headers: @callback_headers.merge(grant_session.user_headers)
      submit_social_completion_if_present!
    end

    assert_redirected_to sign_app_settings_path(ri: "jp")

    identity = ClientAppleIdentity.find_by(uid: "apple_flow_link")

    assert_not_nil identity
    assert_equal user.id, identity.user_id
  end

  test "Sign-started link commits with a logged-in session" do
    user = clients(:one)
    setup_apple_mock_auth(uid: "apple_flow_link_session_only")

    state = start_social_auth_flow(intent: "link", user: user)

    assert_difference("ClientAppleIdentity.count", 1) do
      post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
           params: { state: state },
           headers: @callback_headers.merge(as_user_headers(user, host: @host))
    end

    assert_equal user.id, ClientAppleIdentity.find_by!(uid: "apple_flow_link_session_only").user_id
    assert_not_includes response.body.to_s, "social-completion-form"
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
