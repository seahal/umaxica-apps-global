# typed: false
# frozen_string_literal: true

require "test_helper"

# Integration tests for social auth link intent
#
# These tests verify:
# - MANDATORY TEST 3: Linking a provider+uid already linked to another user -> 409
# - Link with duplicate user_id+provider -> 409
# - Successful link creates identity and associates with current user
class SocialAuthLinkTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  SOCIAL_FLOW_ID_SESSION_KEY = :social_auth_flow_id
  fixtures :clients,
           :client_statuses,
           :client_google_identity_statuses,
           :client_apple_identity_statuses,
           :app_preference_chronicle_levels

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @callback_headers = social_callback_headers(@host)

    # Create test users
    @user_one = clients(:one)
    @user_two = clients(:two)

    # Ensure no pre-existing social identities
    ClientGoogleIdentity.where(user: [@user_one, @user_two]).destroy_all
    ClientAppleIdentity.where(user: [@user_one, @user_two]).destroy_all
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  # ============================================================================
  # MANDATORY TEST 3: Link provider+uid already linked to another user -> 409
  # ============================================================================
  test "link Google identity already linked to another user returns 409 Conflict" do
    existing_uid = "google_owned_by_user_one"

    # First, create identity for user_one
    ClientGoogleIdentity.create!(
      user: @user_one,
      uid: existing_uid,
      provider: "google_app",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    # Setup mock auth with the same uid
    setup_google_mock_auth(uid: existing_uid)

    # Client two tries to link the same Google account
    # Start link flow as user_two
    post continue_sign_app_social_authentication_url(provider: "google_app", intent: "link", ri: "jp"),
         headers: social_link_headers(@user_two)

    assert_response :redirect

    # Callback should fail with conflict
    get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
        params: { state: social_auth_state_from_response },
        headers: @callback_headers.merge(as_user_headers(@user_two, host: @host))

    # Should redirect with error (409 manifested as redirect with flash)
    assert_response :redirect
    follow_redirect!

    # Verify conflict error message
    assert_predicate flash[:alert], :present?, "Should have conflict error"

    # Identity should still belong to user_one
    identity = ClientGoogleIdentity.find_by(uid: existing_uid)

    assert_equal @user_one.id, identity.user_id, "Identity should still belong to original user"
  end

  test "link Apple identity already linked to another user returns 409 Conflict" do
    existing_uid = "apple_owned_by_user_one"

    ClientAppleIdentity.create!(
      user: @user_one,
      uid: existing_uid,
      provider: "apple",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    setup_apple_mock_auth(uid: existing_uid)

    # Client two starts link flow
    post continue_sign_app_social_authentication_url(provider: "apple", intent: "link", ri: "jp"),
         headers: social_link_headers(@user_two)

    assert_response :redirect

    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         params: { state: social_auth_state_from_response },
         headers: @callback_headers.merge(as_user_headers(@user_two, host: @host))

    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:alert], :present?, "Should have conflict error for Apple"

    identity = ClientAppleIdentity.find_by(uid: existing_uid)

    assert_equal @user_one.id, identity.user_id
  end

  test "link Apple fails when flow context is missing" do
    setup_apple_mock_auth(uid: "apple_state_mismatch_#{SecureRandom.hex(4)}")

    # Do not call /social/auth/:provider/continue to simulate missing link context
    # Use X-STRICT-SOCIAL-STATE to prevent test-mode state bypass
    post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
         headers: @callback_headers.merge(as_user_headers(@user_one, host: @host))
           .merge("X-STRICT-SOCIAL-STATE" => "1")

    assert_response :forbidden

    identity = ClientAppleIdentity.find_by(uid: OmniAuth.config.mock_auth[:apple].uid)

    assert_nil identity, "Identity should not be created on state mismatch"
  end

  test "link Apple fails when intent TTL exceeded" do
    setup_apple_mock_auth(uid: "apple_state_expired_#{SecureRandom.hex(4)}")

    post continue_sign_app_social_authentication_url(provider: "apple", intent: "link", ri: "jp"),
         headers: social_link_headers(@user_one)

    assert_response :redirect

    travel_to 6.minutes.from_now do
      post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
           params: { state: social_auth_state_from_response },
           headers: @callback_headers.merge(as_user_headers(@user_one, host: @host))
    end

    assert_response :forbidden

    identity = ClientAppleIdentity.find_by(uid: OmniAuth.config.mock_auth[:apple].uid)

    assert_nil identity, "Identity should not be created when intent expired"
  end

  test "Sign-owned Google link intent creates one social identity" do
    new_uid = "grantless_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    post continue_sign_app_social_authentication_url(provider: "google_app", intent: "link", ri: "jp"),
         headers: social_link_headers(@user_one)

    assert_difference("ClientGoogleIdentity.count", 1) do
      get sign_app_auth_callback_url(provider: "google_app", ri: "jp"),
          params: { state: social_auth_state_from_response },
          headers: @callback_headers.merge(as_user_headers(@user_one, host: @host))
    end

    assert_redirected_to sign_app_settings_path(ri: "jp")
    assert_equal @user_one.id, ClientGoogleIdentity.find_by!(uid: new_uid).user_id
    assert_not_includes response.body.to_s, "social-completion-form"
  end

  test "Sign-owned Apple link intent creates one social identity" do
    new_uid = "grantless_apple_#{SecureRandom.hex(4)}"
    setup_apple_mock_auth(uid: new_uid)

    post continue_sign_app_social_authentication_url(provider: "apple", intent: "link", ri: "jp"),
         headers: social_link_headers(@user_one)

    assert_difference("ClientAppleIdentity.count", 1) do
      post sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
           params: { state: social_auth_state_from_response },
           headers: @callback_headers.merge(as_user_headers(@user_one, host: @host))
    end

    assert_redirected_to sign_app_settings_path(ri: "jp")
    assert_equal @user_one.id, ClientAppleIdentity.find_by!(uid: new_uid).user_id
  end

  # ============================================================================
  # OPTIONAL: Client already has this provider linked (update case)
  # ============================================================================
  test "Sign link when user already has this provider updates existing identity" do
    old_uid = "old_google_uid"

    # Client one already has Google linked
    existing_identity = ClientGoogleIdentity.create!(
      user: @user_one,
      uid: old_uid,
      provider: "google_app",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    # Re-link the same provider+uid through the Sign-owned settings ceremony.
    setup_google_mock_auth(uid: old_uid)
    grant_session = seed_app_social_link_grant_session(provider: "google_app", user: @user_one, ri: "jp")

    perform_grant_backed_link(provider: "google_app", grant_session: grant_session)

    assert_redirected_to sign_app_settings_path(ri: "jp")
    # Identity should still exist and remain owned by the same user.
    existing_identity.reload

    assert_equal @user_one.id, existing_identity.user_id
  end

  test "successful Sign-owned Google link creates identity for current user" do
    new_uid = "brand_new_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    grant_session = seed_app_social_link_grant_session(provider: "google_app", user: @user_one, ri: "jp")

    assert_difference("ClientGoogleIdentity.count", 1) do
      perform_grant_backed_link(provider: "google_app", grant_session: grant_session)
    end

    assert_redirected_to sign_app_settings_path(ri: "jp")

    # New identity created on Sign under the current user.
    identity = ClientGoogleIdentity.find_by(uid: new_uid)

    assert_not_nil identity
    assert_equal @user_one.id, identity.user_id, "Identity should belong to current user"
    assert_not_nil identity.last_authenticated_at, "last_authenticated_at should be set"
  end

  test "link intent requires authentication" do
    setup_google_mock_auth(uid: "unauthenticated_test")

    # Start without authentication headers
    post continue_sign_app_social_authentication_url(provider: "google_app", intent: "link", ri: "jp"),
         headers: { "Host" => @host }

    # Should redirect to login or return error
    assert_response :redirect
    follow_redirect!

    assert_predicate flash[:alert], :present?, "Should require login for link intent"
  end

  test "link intent rejects resource-level step up without token-bound step up" do
    @user_one.update!(last_step_up_at: Time.current)

    post continue_sign_app_social_authentication_url(provider: "google_app", intent: "link", ri: "jp"),
         headers: as_user_headers(@user_one, host: @host)

    assert_response :see_other
    assert_match %r{/verification}, response.location
    assert_match "scope=social_link", response.location
    assert_nil session[SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "link intent rejects token-bound step up for a different scope" do
    headers = as_user_headers(@user_one, host: @host)
    token = ClientToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    post continue_sign_app_social_authentication_url(provider: "google_app", intent: "link", ri: "jp"),
         headers: headers

    assert_response :see_other
    assert_match %r{/verification}, response.location
    assert_match "scope=social_link", response.location
    assert_nil session[SOCIAL_FLOW_ID_SESSION_KEY]
  end

  # ============================================================================
  # Re-linking REVOKED identity (idempotency test)
  # ============================================================================
  test "re-link REVOKED Google identity reactivates it" do
    revoked_uid = "revoked_google_#{SecureRandom.hex(4)}"

    # Create a REVOKED identity for user_one
    revoked_identity = ClientGoogleIdentity.create!(
      user: @user_one,
      uid: revoked_uid,
      provider: "google_app",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:revoked),
    )

    # Setup mock auth with the same uid but updated info
    setup_google_mock_auth(uid: revoked_uid)

    # Re-link through the Sign-owned settings ceremony.
    grant_session = seed_app_social_link_grant_session(provider: "google_app", user: @user_one, ri: "jp")
    perform_grant_backed_link(provider: "google_app", grant_session: grant_session)

    assert_redirected_to sign_app_settings_path(ri: "jp")

    # Identity should be reactivated (status changed to ACTIVE)
    revoked_identity.reload

    assert_equal ClientGoogleIdentityStatus::ACTIVE, revoked_identity.status_id,
                 "Identity should be ACTIVE"
  end

  test "re-link REVOKED Apple identity reactivates it" do
    revoked_uid = "revoked_apple_#{SecureRandom.hex(4)}"

    revoked_identity = ClientAppleIdentity.create!(
      user: @user_one,
      uid: revoked_uid,
      provider: "apple",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:revoked),
    )

    setup_apple_mock_auth(uid: revoked_uid)

    grant_session = seed_app_social_link_grant_session(provider: "apple", user: @user_one, ri: "jp")
    perform_grant_backed_link(provider: "apple", grant_session: grant_session)

    assert_redirected_to sign_app_settings_path(ri: "jp")

    revoked_identity.reload

    assert_equal ClientAppleIdentityStatus::ACTIVE, revoked_identity.status_id,
                 "Apple identity should be ACTIVE"
  end

  private

  def perform_grant_backed_link(provider:, grant_session:)
    if provider == "apple"
      post(
        sign_app_auth_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: grant_session.state },
        headers: @callback_headers.merge(grant_session.user_headers),
      )
    else
      get(
        sign_app_auth_callback_url(provider: provider, ri: "jp"),
        params: { state: grant_session.state },
        headers: @callback_headers.merge(grant_session.user_headers),
      )
    end
    submit_social_completion_if_present!
  end

  def social_link_headers(user)
    headers = as_user_headers(user, host: @host)
    token = ClientToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    mark_token_step_up_satisfied_for_test(token, scope: SocialAuth::SOCIAL_LINK_SCOPE)
    headers
  end

  # IMPORTANT: Social login authenticates by provider+uid ONLY, NOT email
  # We deliberately omit email from mock_auth to test this requirement
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

  def social_auth_state_from_response
    session[:social_auth_state].presence ||
      begin
        uri = URI.parse(response.location.to_s)
        Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
      rescue URI::InvalidURIError
        nil
      end
  end
end
