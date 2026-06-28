# typed: false
# frozen_string_literal: true

require "test_helper"

# Integration tests for Sign-owned social settings link and login separation.
#
# IMPORTANT: A logged-in user may link only through a Sign-started server-side
# `intent=link` flow. Unauthenticated login callbacks for unknown identities stay
# pending-confirmation and must not create durable identities at callback time.
class SocialAuthAutoLinkTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_google_identity_statuses, :client_apple_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("PRIVATE_SIGN_SERVICE_URL")
    @callback_headers = social_callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  # ============================================================================
  # a) Sign-started settings link commits on sign.
  # ============================================================================
  test "logged-in user: Sign-started Apple link commits on sign" do
    # Create and login as user
    user = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "user_#{SecureRandom.hex(4)}")
    ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    # Mock Apple auth (NO email)
    apple_uid = "apple_auto_link_#{SecureRandom.hex(4)}"

    state = start_social_auth_flow(provider: "apple", intent: "link", user: user)
    setup_apple_mock_auth(uid: apple_uid)
    assert_difference("ClientAppleIdentity.count", 1) do
      post auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
           params: { state: state },
           headers: @callback_headers.merge(as_user_headers(user, host: @host))
    end

    user.reload

    assert_equal apple_uid, user.user_apple_identity.uid

    # No new Client created either.
    assert_equal 1, Client.where(id: user.id).count
  end

  test "logged-in user: Sign-started Google link commits on sign" do
    # Create and login as user
    user = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "user_#{SecureRandom.hex(4)}")
    ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    # Mock Google auth (NO email)
    google_uid = "google_auto_link_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: google_uid)

    state = start_social_auth_flow(provider: "google", intent: "link", user: user)
    assert_difference("ClientGoogleIdentity.count", 1) do
      get auth_app_social_google_callback_url(ri: "jp"),
          params: { state: state },
          headers: @callback_headers.merge(as_user_headers(user, host: @host))
    end

    user.reload

    assert_equal google_uid, user.user_google_identity.uid
  end

  # ============================================================================
  # b) Repeated Sign-started callbacks do not create duplicate identities.
  # ============================================================================
  test "Sign-started Apple callbacks remain single-identity across repeated attempts" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "user_#{SecureRandom.hex(4)}")
    ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    apple_uid = "apple_idempotent_#{SecureRandom.hex(4)}"

    2.times do
      state = start_social_auth_flow(provider: "apple", intent: "link", user: user)
      setup_apple_mock_auth(uid: apple_uid)
      post auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
           params: { state: state },
           headers: @callback_headers.merge(as_user_headers(user, host: @host))
    end

    user.reload

    assert_equal apple_uid, user.user_apple_identity.uid
    assert_equal 1, ClientAppleIdentity.where(uid: apple_uid).count
  end

  # ============================================================================
  # c) Settings link cannot reassign an identity owned by another user
  # ============================================================================
  test "Sign-started Apple link cannot steal a uid linked to a different user" do
    # Create userA and link Apple identity
    user_a = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "userA_#{SecureRandom.hex(4)}")
    apple_uid = "apple_conflict_#{SecureRandom.hex(4)}"
    ClientAppleIdentity.create!(
      user: user_a,
      uid: apple_uid,
      provider: "apple",
      token: "token_a",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    # Create userB and try to link the SAME Apple uid
    user_b = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "userB_#{SecureRandom.hex(4)}")
    ClientToken.create!(user: user_b, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    # Callback as userB must be rejected before any reassignment.
    state = start_social_auth_flow(provider: "apple", intent: "link", user: user_b)
    setup_apple_mock_auth(uid: apple_uid)
    post auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: @callback_headers.merge(as_user_headers(user_b, host: @host))

    assert_response :redirect

    # userB should NOT have ClientAppleIdentity
    user_b.reload

    assert_nil user_b.user_apple_identity, "userB should NOT have Apple identity"

    # userA should still own the identity
    user_a.reload

    assert_equal apple_uid, user_a.user_apple_identity.uid
    assert_equal user_a.id, ClientAppleIdentity.find_by(uid: apple_uid).user_id
  end

  test "not logged in: Apple callback creates new user (login flow, not link)" do
    apple_uid = "apple_new_user_#{SecureRandom.hex(4)}"

    user_count_before = Client.count

    # Start OAuth flow to set up session state (required by SocialCallbackGuard)
    state = start_social_auth_flow(provider: "apple", intent: "login")
    setup_apple_mock_auth(uid: apple_uid)

    # Callback without login (no headers)
    post auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: browser_headers.merge(@callback_headers)

    assert_response :redirect

    assert_equal user_count_before, Client.count

    identity = ClientAppleIdentity.find_by(uid: apple_uid)

    assert_nil identity
  end

  private

  # IMPORTANT: Social login uses provider+uid ONLY, NOT email
  def setup_google_mock_auth(uid:)
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: uid,
      info: { image: "https://example.com/image.jpg" },
      credentials: {
        token: "google_token_#{SecureRandom.hex(8)}",
        refresh_token: "refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )
  end

  def setup_apple_mock_auth(uid:)
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {},
      credentials: {
        token: "apple_token_#{SecureRandom.hex(8)}",
        expires_at: 1.week.from_now.to_i,
      },
      extra: { id_info: { nonce: session[:social_auth_nonce] } },
    )
  end

  def start_social_auth_flow(provider:, intent:, user: nil)
    seed_social_auth_session(provider: provider, intent: intent, user: user, ri: "jp")
  end
end
