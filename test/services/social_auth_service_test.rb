# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    # Ensure UserSocialGoogleStatus and UserSocialGoogle exist and are used correctly
    @status = UserSocialGoogleStatus.find_or_create_by!(id: UserSocialGoogleStatus::ACTIVE)
    @identity =
      UserSocialGoogle.find_or_create_by!(uid: "uid123", provider: "google") do |id|
        id.user = @user
        id.token = "token123"
        id.expires_at = 1.hour.from_now.to_i
        id.status_id = @status.id
      end

    # Add a verified email to have 2 login methods (Google + Email)
    # This ensures login_methods_remaining? returns true without stubbing
    verified_email_status =
      UserEmailStatus.find_or_create_by!(id: UserEmailStatus::VERIFIED) do |s|
        s.name = "verified"
      end
    UserEmail.create!(
      user: @user,
      address: "test-#{SecureRandom.hex(4)}@example.com",
      address_digest: "digest-#{SecureRandom.hex(8)}",
      user_email_status_id: verified_email_status.id,
      public_id: SecureRandom.alphanumeric(21),
    )

    @auth_hash = Struct.new(:provider, :uid, :credentials, :info).new(
      "google",
      "uid123",
      Struct.new(:token, :refresh_token, :expires_at).new("token123", "refresh123", 1.hour.from_now.to_i),
      Struct.new(:email).new("test@example.com"),
    )
  end

  test "handle_callback for existing google identity" do
    result = SocialAuthService.handle_callback(
      auth_hash: @auth_hash,
      current_user: nil,
      intent: "login",
    )

    assert_equal @user.id, result[:user].id
    assert_equal @identity.id, result[:identity].id
    assert_equal @user.id, result[:jwt_payload][:user_id]
  end

  test "handle_callback records google signup audit for new identity" do
    auth_hash = {
      "provider" => "google",
      "uid" => "new-google-signup-#{SecureRandom.hex(8)}",
      "credentials" => {
        "token" => "new-google-token",
        "refresh_token" => "new-google-refresh",
        "expires_at" => 1.hour.from_now.to_i,
      },
    }

    assert_difference -> { UserChronicle.where(event_id: UserChronicleEvent::SIGNED_UP_WITH_GOOGLE).count }, 1 do
      result = SocialAuthService.handle_callback(
        auth_hash: auth_hash,
        current_user: nil,
        intent: "login",
      )

      audit = UserChronicle.order(created_at: :desc).find_by!(
        event_id: UserChronicleEvent::SIGNED_UP_WITH_GOOGLE,
        subject_id: result[:user].id,
        subject_type: "User",
      )

      assert_equal result[:user].id, audit.actor_id
      assert_equal "User", audit.actor_type
      assert_equal "social", audit.context["auth_method"]
      assert_equal "google", audit.context["provider"]
    end
  end

  test "handle_callback records google link audit for new linked identity" do
    user = User.create!(status_id: UserStatus::NOTHING)
    auth_hash = {
      "provider" => "google",
      "uid" => "linked-google-#{SecureRandom.hex(8)}",
      "credentials" => {
        "token" => "linked-google-token",
        "refresh_token" => "linked-google-refresh",
        "expires_at" => 1.hour.from_now.to_i,
      },
    }

    assert_difference -> { UserChronicle.where(event_id: UserChronicleEvent::SOCIAL_LINKED).count }, 1 do
      result = SocialAuthService.handle_callback(
        auth_hash: auth_hash,
        current_user: user,
        intent: "link",
      )

      audit = UserChronicle.order(created_at: :desc).find_by!(
        event_id: UserChronicleEvent::SOCIAL_LINKED,
        subject_id: user.id,
        subject_type: "User",
      )

      assert_equal user.id, result[:user].id
      assert_equal user.id, audit.actor_id
      assert_equal "social", audit.context["auth_method"]
      assert_equal "google", audit.context["provider"]
      assert_equal "UserSocialGoogle", audit.context["social_identity_type"]
    end
  end

  test "unlink records user-scoped social unlink audit" do
    apple_status = UserSocialAppleStatus.find_or_create_by!(id: UserSocialAppleStatus::ACTIVE)
    UserSocialApple.create!(
      user: @user,
      uid: "apple-backup-#{SecureRandom.hex(8)}",
      provider: "apple",
      token: "apple-token",
      expires_at: 1.hour.from_now.to_i,
      status_id: apple_status.id,
    )

    assert_difference -> { UserChronicle.where(event_id: UserChronicleEvent::SOCIAL_UNLINKED).count }, 1 do
      result = SocialAuthService.unlink(provider: "google", user: @user)

      audit = UserChronicle.order(created_at: :desc).find_by!(
        event_id: UserChronicleEvent::SOCIAL_UNLINKED,
        subject_id: @user.id,
        subject_type: "User",
      )

      assert result[:success]
      assert_equal @user.id, audit.actor_id
      assert_equal "social", audit.context["auth_method"]
      assert_equal "google", audit.context["provider"]
      assert_equal "UserSocialGoogle", audit.context["social_identity_type"]
    end
  end

  test "handle_callback raises error for invalid intent" do
    assert_raises(SocialAuth::UnauthorizedError) do
      SocialAuthService.handle_callback(
        auth_hash: @auth_hash,
        current_user: nil,
        intent: "invalid",
      )
    end
  end

  test "unlink google identity" do
    # User now has 2 login methods: Google + Email (set up in setup)
    # login_methods_remaining? returns true without stubbing
    result = SocialAuthService.unlink(provider: "google", user: @user)

    assert result[:success]
    assert_equal "google", result[:provider]
    assert_not UserSocialGoogle.exists?(@identity.id)
  end
end
