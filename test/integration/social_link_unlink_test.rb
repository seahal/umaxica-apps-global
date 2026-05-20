# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialLinkUnlinkTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_secret_kinds, :client_secret_statuses, :client_social_apple_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    @user = create_verified_user_with_email(email_address: "social_link_test@example.com")
    # Ensure @user has at least one auth method to start (e.g. password secret)
    # Check fixtures or add one.
    # Note: ClientSecretKind should be seeded. If validation fails, check seeded values.
    ClientSecretKind.find_or_create_by!(id: ClientSecretKind::LOGIN)
    ClientSecretStatus.find_or_create_by!(id: ClientSecretStatus::ACTIVE)
    ClientSocialAppleStatus.find_or_create_by!(id: ClientSocialAppleStatus::ACTIVE)
    ClientSocialAppleStatus.find_or_create_by!(id: ClientSocialAppleStatus::REVOKED)

    ClientSecret.create!(
      user: @user,
      user_secret_kind_id: ClientSecretKind::LOGIN,
      password_digest: "digest",
      name: "default",
    )

    # Login as user
    @headers = as_user_headers(@user, host: @host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
  end

  test "should unlink apple account when another identity exists" do
    # Create Apple identity directly (link flow is handled elsewhere)
    ClientSocialApple.create!(
      user: @user, uid: "apple_uid_link", provider: "apple",
      token: "t", token_expires_at: 1.hour.from_now.to_i,
    )
    satisfy_user_verification(@token)

    delete sign_app_social_authentication_url(provider: "apple", ri: "jp"), headers: @headers

    assert_redirected_to sign_app_configuration_url(ri: "jp")
    follow_redirect!(headers: @headers)

    assert_equal I18n.t("sign.app.social.sessions.unlink.success", provider: "Apple"), flash[:notice]
    assert_nil ClientSocialApple.find_by(uid: "apple_uid_link")
  end

  test "should prevent unlinking last identity" do
    # Create user with ONLY Apple identity (remove password secret)
    @user.client_secrets.destroy_all
    @user.client_emails.destroy_all

    ClientSocialApple.create!(
      user: @user, uid: "apple_uid_solo", provider: "apple",
      token: "t", token_expires_at: 1.hour.from_now.to_i,
    )
    satisfy_user_verification(@token)

    # Try to unlink Apple
    delete sign_app_social_authentication_url(provider: "apple", ri: "jp"), headers: @headers

    assert_response :redirect
    assert_redirected_to sign_app_configuration_url(ri: "jp")
    follow_redirect!(headers: @headers)

    assert_equal I18n.t("errors.social_auth.insufficient_login_methods"), flash[:alert]

    # Ensure it wasn't destroyed
    assert ClientSocialApple.find_by(uid: "apple_uid_solo")
  end
end
