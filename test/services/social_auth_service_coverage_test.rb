# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthServiceCoverageTest < ActiveSupport::TestCase
  setup do
    @user = clients(:one)
    ClientStatus.find_or_create_by!(id: 1)
    ClientGoogleIdentityStatus.find_or_create_by!(id: ClientGoogleIdentityStatus::ACTIVE)
    ClientGoogleIdentityStatus.find_or_create_by!(id: ClientGoogleIdentityStatus::REVOKED)
    ClientAppleIdentityStatus.find_or_create_by!(id: ClientAppleIdentityStatus::ACTIVE)
    ClientAppleIdentityStatus.find_or_create_by!(id: ClientAppleIdentityStatus::REVOKED)
    ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
  end

  test "handle_login returns pending signup for unknown identity" do
    auth_hash = OmniAuth::AuthHash.new(
      {
        "provider" => "google",
        "uid" => "new-uid",
        "credentials" => { "token" => "t", "expires_at" => 0 },
      },
    )

    assert_no_difference -> { Client.count } do
      assert_no_difference -> { ClientGoogleIdentity.count } do
        result = SocialAuthService.handle_callback(auth_hash: auth_hash, current_client: nil, intent: "login")

        assert_nil result[:user]
        assert_nil result[:identity]
        assert result[:pending_social_signup]
        assert_equal "new-uid", result[:uid]
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

    assert_difference -> { ClientAppleIdentity.count }, 1 do
      result = SocialAuthService.handle_callback(auth_hash: auth_hash, current_client: @user, intent: "link")

      assert_equal @user.id, result[:user].id
      assert_equal "apple-link", result[:identity].uid
    end
  end

  test "handle_link_raises_conflict_if_linked_to_another_user" do
    other_user = clients(:two)
    ClientGoogleIdentity.create!(
      user: other_user,
      uid: "other-uid",
      provider: "google",
      status_id: ClientGoogleIdentityStatus::ACTIVE,
      token: "t", token_expires_at: 0,
    )

    auth_hash = OmniAuth::AuthHash.new({ "provider" => "google", "uid" => "other-uid" })

    assert_raises(SocialAuth::ConflictError) do
      SocialAuthService.handle_callback(auth_hash: auth_hash, current_client: @user, intent: "link")
    end
  end

  test "step_up intent is rejected" do
    ClientGoogleIdentity.create!(
      user: @user,
      uid: "step-up-forbidden-uid",
      provider: "google",
      status_id: ClientGoogleIdentityStatus::ACTIVE,
      token: "t", token_expires_at: 0,
    )
    auth_hash = OmniAuth::AuthHash.new(
      {
        "provider" => "google",
        "uid" => "step-up-forbidden-uid",
        "credentials" => { "token" => "new-t", "expires_at" => 100 },
      },
    )

    assert_raises(SocialAuth::UnauthorizedError) do
      SocialAuthService.handle_callback(auth_hash: auth_hash, current_client: @user, intent: "step_up")
    end

    assert_nil @user.reload.last_step_up_at
  end
end
