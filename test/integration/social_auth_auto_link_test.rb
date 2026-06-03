# typed: false
# frozen_string_literal: true

require "test_helper"

# Integration tests for the grantless auto-link path when a user is already
# logged in.
#
# IMPORTANT: Final social-link commit is acme authority. A logged-in user who
# completes a provider callback WITHOUT an acme-issued ceremony grant (the
# "auto-link" path) must NOT have a social identity created or mutated on sign.
# These tests pin that the sign callback rejects the grantless link instead of
# committing it inline.
class SocialAuthAutoLinkTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_google_identity_statuses, :client_apple_identity_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("SIGN_SERVICE_URL", "id.umaxica.app")
    @callback_headers = social_callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  # ============================================================================
  # a) Grantless auto-link is rejected on sign (no inline commit)
  # ============================================================================
  test "logged-in user: grantless Apple callback does not link on sign" do
    # Create and login as user
    user = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "user_#{SecureRandom.hex(4)}")
    ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    # Mock Apple auth (NO email)
    apple_uid = "apple_auto_link_#{SecureRandom.hex(4)}"
    setup_apple_mock_auth(uid: apple_uid)

    # Simulate grantless Apple callback as logged-in user
    state = start_social_auth_flow(provider: "apple", intent: "link", user: user)
    assert_no_difference("ClientAppleIdentity.count") do
      post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
           params: { state: state },
           headers: @callback_headers.merge(as_user_headers(user, host: @host))
    end

    # CRITICAL: sign must NOT create the identity for a grantless link.
    user.reload

    assert_nil user.user_apple_identity, "sign must not commit a grantless auto-link"
    assert_nil ClientAppleIdentity.find_by(uid: apple_uid)

    # No new Client created either.
    assert_equal 1, Client.where(id: user.id).count
  end

  test "logged-in user: grantless Google callback does not link on sign" do
    # Create and login as user
    user = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "user_#{SecureRandom.hex(4)}")
    ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    # Mock Google auth (NO email)
    google_uid = "google_auto_link_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: google_uid)

    # Simulate grantless Google callback as logged-in user
    state = start_social_auth_flow(provider: "google_app", intent: "link", user: user)
    assert_no_difference("ClientGoogleIdentity.count") do
      get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
          params: { state: state },
          headers: @callback_headers.merge(as_user_headers(user, host: @host))
    end

    # CRITICAL: sign must NOT create the identity for a grantless link.
    user.reload

    assert_nil user.user_google_identity, "sign must not commit a grantless auto-link"
    assert_nil ClientGoogleIdentity.find_by(uid: google_uid)
  end

  # ============================================================================
  # b) Repeated grantless callbacks never create an identity on sign
  # ============================================================================
  test "grantless Apple callback stays non-committing across repeated attempts" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "user_#{SecureRandom.hex(4)}")
    ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    apple_uid = "apple_idempotent_#{SecureRandom.hex(4)}"

    2.times do
      setup_apple_mock_auth(uid: apple_uid)
      state = start_social_auth_flow(provider: "apple", intent: "link", user: user)
      post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
           params: { state: state },
           headers: @callback_headers.merge(as_user_headers(user, host: @host))
    end

    # Still no identity created on sign after repeated grantless attempts.
    user.reload

    assert_nil user.user_apple_identity
    assert_equal 0, ClientAppleIdentity.where(uid: apple_uid).count
  end

  # ============================================================================
  # c) Grantless link cannot reassign an identity owned by another user
  # ============================================================================
  test "grantless Apple callback cannot steal a uid linked to a different user" do
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

    # Create userB and try to grantless-link the SAME Apple uid
    user_b = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "userB_#{SecureRandom.hex(4)}")
    ClientToken.create!(user: user_b, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    setup_apple_mock_auth(uid: apple_uid)

    # Callback as userB must be rejected before any reassignment.
    state = start_social_auth_flow(provider: "apple", intent: "link", user: user_b)
    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
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
    setup_apple_mock_auth(uid: apple_uid)

    user_count_before = Client.count

    # Start OAuth flow to set up session state (required by SocialCallbackGuard)
    state = start_social_auth_flow(provider: "apple", intent: "login")

    # Callback without login (no headers)
    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: state },
         headers: browser_headers.merge(@callback_headers)

    assert_response :redirect

    # Should create NEW user (login flow)
    assert_equal user_count_before + 1, Client.count

    # ClientAppleIdentity should exist
    identity = ClientAppleIdentity.find_by(uid: apple_uid)

    assert_not_nil identity
    assert_not_nil identity.user
  end

  private

  # IMPORTANT: Social login uses provider+uid ONLY, NOT email
  def setup_google_mock_auth(uid:)
    OmniAuth.config.mock_auth[:google_app] = OmniAuth::AuthHash.new(
      provider: "google_app",
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
    )
  end

  def start_social_auth_flow(provider:, intent:, user: nil)
    seed_social_auth_session(provider: provider, intent: intent, user: user, ri: "jp")
  end
end
