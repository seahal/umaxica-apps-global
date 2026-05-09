# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthServiceCoverageTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    UserStatus.find_or_create_by!(id: 1)
    UserSocialGoogleStatus.find_or_create_by!(id: UserSocialGoogleStatus::ACTIVE)
    UserSocialGoogleStatus.find_or_create_by!(id: UserSocialGoogleStatus::REVOKED)
    UserSocialAppleStatus.find_or_create_by!(id: UserSocialAppleStatus::ACTIVE)
    UserSocialAppleStatus.find_or_create_by!(id: UserSocialAppleStatus::REVOKED)
    UserChronicleLevel.find_or_create_by!(id: UserChronicleLevel::NOTHING)
  end

  test "extract_uid falls back to Apple id_token" do
    key = OpenSSL::PKey::RSA.generate(2048)
    id_token = JWT.encode({ sub: "apple-uid" }, key, "RS256")

    auth_hash = OmniAuth::AuthHash.new(
      {
        "provider" => "apple",
        "credentials" => { "id_token" => id_token },
      },
    )

    service = SocialAuthService.new(auth_hash: auth_hash, current_user: nil, intent: "login")

    assert_equal "apple-uid", service.send(:extract_uid)
  end

  test "extract_uid_from_id_token handles decode error" do
    auth_hash = OmniAuth::AuthHash.new({ "credentials" => { "id_token" => "invalid" } })
    service = SocialAuthService.new(auth_hash: auth_hash, current_user: nil, intent: "login")

    assert_nil service.send(:extract_uid_from_id_token)
  end

  test "handle_login creates new user and identity" do
    auth_hash = OmniAuth::AuthHash.new(
      {
        "provider" => "google",
        "uid" => "new-uid",
        "credentials" => { "token" => "t", "expires_at" => 0 },
      },
    )

    assert_difference -> { User.count }, 1 do
      assert_difference -> { UserSocialGoogle.count }, 1 do
        result = SocialAuthService.handle_callback(auth_hash: auth_hash, current_user: nil, intent: "login")

        assert_not_nil result[:user]
        assert_equal "new-uid", result[:identity].uid
      end
    end
  end

  test "handle_link links new identity to current user" do
    auth_hash = OmniAuth::AuthHash.new(
      {
        "provider" => "apple",
        "uid" => "apple-link",
        "credentials" => { "token" => "t", "expires_at" => 0 },
      },
    )

    assert_difference -> { UserSocialApple.count }, 1 do
      result = SocialAuthService.handle_callback(auth_hash: auth_hash, current_user: @user, intent: "link")

      assert_equal @user.id, result[:user].id
      assert_equal "apple-link", result[:identity].uid
    end
  end

  test "handle_link_raises_conflict_if_linked_to_another_user" do
    other_user = users(:two)
    UserSocialGoogle.create!(
      user: other_user,
      uid: "other-uid",
      provider: "google",
      status_id: UserSocialGoogleStatus::ACTIVE,
      token: "t", token_expires_at: 0,
    )

    auth_hash = OmniAuth::AuthHash.new({ "provider" => "google", "uid" => "other-uid" })

    assert_raises(SocialAuth::ConflictError) do
      SocialAuthService.handle_callback(auth_hash: auth_hash, current_user: @user, intent: "link")
    end
  end

  test "handle_reauth updates last_reauth_at" do
    UserSocialGoogle.create!(
      user: @user,
      uid: "reauth-uid",
      provider: "google",
      status_id: UserSocialGoogleStatus::ACTIVE,
      token: "t", token_expires_at: 0,
    )
    auth_hash = OmniAuth::AuthHash.new(
      {
        "provider" => "google",
        "uid" => "reauth-uid",
        "credentials" => { "token" => "new-t", "expires_at" => 100 },
      },
    )

    result = SocialAuthService.handle_callback(auth_hash: auth_hash, current_user: @user, intent: "reauth")

    assert result[:reauthenticated]
    assert_not_nil result[:user].last_reauth_at
  end

  test "extract_uid_from_id_token rejects disallowed algorithm" do
    key = OpenSSL::PKey::RSA.generate(2048)
    # Using a disallowed algorithm if possible, or just mock the header
    id_token = JWT.encode({ sub: "uid" }, key, "RS512") # RS512 is not in ALLOWED_ID_TOKEN_ALGORITHMS

    auth_hash = OmniAuth::AuthHash.new({ "credentials" => { "id_token" => id_token } })
    service = SocialAuthService.new(auth_hash: auth_hash, current_user: nil, intent: "login")

    assert_nil service.send(:extract_uid_from_id_token)
  end
end
