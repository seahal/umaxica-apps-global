# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthServiceTest < ActiveSupport::TestCase
  setup do
    @user = clients(:one)
    # Ensure ClientSocialGoogleStatus and ClientSocialGoogle exist and are used correctly
    @status = ClientSocialGoogleStatus.find_or_create_by!(id: ClientSocialGoogleStatus::ACTIVE)
    @identity =
      ClientSocialGoogle.find_or_create_by!(uid: "uid123", provider: "google") do |id|
        id.user = @user
        id.token = "token123"
        id.expires_at = 1.hour.from_now.to_i
        id.status_id = @status.id
      end

    # Add a verified email to have 2 login methods (Google + Email)
    # This ensures login_methods_remaining? returns true without stubbing
    verified_email_status =
      ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED) do |s|
        s.name = "verified"
      end
    ClientEmail.create!(
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
      current_client: nil,
      intent: "login",
    )

    assert_equal @user.id, result[:user].id
    assert_equal @identity.id, result[:identity].id
    assert_equal @user.id, result[:jwt_payload][:user_id]
  end

  test "handle_callback rejects org google provider on app social service" do
    auth_hash = {
      "provider" => "google_org",
      "uid" => "org-google-#{SecureRandom.hex(8)}",
      "credentials" => {
        "token" => "token",
      },
    }

    assert_raises(SocialAuth::ProviderError) do
      SocialAuthService.handle_callback(
        auth_hash: auth_hash,
        current_client: nil,
        intent: "login",
      )
    end
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

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE).count }, 1 do
      result = SocialAuthService.handle_callback(
        auth_hash: auth_hash,
        current_client: nil,
        intent: "login",
      )

      audit = ClientChronicle.order(created_at: :desc).find_by!(
        event_id: ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE,
        subject_id: result[:user].id,
        subject_type: "Client",
      )

      assert_equal result[:user].id, audit.actor_id
      assert_equal ClientMultiFactorStatus::UNCONFIGURED, result[:user].multi_factor_status_id
      assert_equal "Client", audit.actor_type
      assert_equal "social", audit.context["auth_method"]
      assert_equal "google", audit.context["provider"]
    end
  end

  test "handle_callback for sign up entry creates pending identity without finalization side effects" do
    auth_hash = {
      "provider" => "google",
      "uid" => "new-google-signup-entry-#{SecureRandom.hex(8)}",
      "credentials" => {
        "token" => "new-google-token",
        "refresh_token" => "new-google-refresh",
        "expires_at" => 1.hour.from_now.to_i,
      },
    }

    assert_no_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE).count } do
      result = SocialAuthService.handle_callback(
        auth_hash: auth_hash,
        current_client: nil,
        intent: "login",
        sign_up_entry: true,
      )

      assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, result[:user].status_id
      assert_nil result[:user].rp_account
      assert_not result[:existing_account]
      assert_equal result[:user].id, result[:identity].user_id
    end
  end

  test "handle_callback creates apple signup user with unconfigured multi factor status" do
    ClientSocialAppleStatus.find_or_create_by!(id: ClientSocialAppleStatus::ACTIVE)
    auth_hash = {
      "provider" => "apple",
      "uid" => "new-apple-signup-#{SecureRandom.hex(8)}",
      "credentials" => {
        "token" => "new-apple-token",
        "expires_at" => 1.hour.from_now.to_i,
      },
    }

    result = SocialAuthService.handle_callback(
      auth_hash: auth_hash,
      current_client: nil,
      intent: "login",
    )

    assert_equal ClientMultiFactorStatus::UNCONFIGURED, result[:user].multi_factor_status_id
    assert_equal result[:user].id, result[:identity].user_id
    assert_equal "apple", result[:identity].provider
  end

  test "handle_callback records google link audit for new linked identity" do
    user = Client.create!(status_id: ClientStatus::NOTHING)
    auth_hash = {
      "provider" => "google",
      "uid" => "linked-google-#{SecureRandom.hex(8)}",
      "credentials" => {
        "token" => "linked-google-token",
        "refresh_token" => "linked-google-refresh",
        "expires_at" => 1.hour.from_now.to_i,
      },
    }

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SOCIAL_LINKED).count }, 1 do
      result = SocialAuthService.handle_callback(
        auth_hash: auth_hash,
        current_client: user,
        intent: "link",
      )

      audit = ClientChronicle.order(created_at: :desc).find_by!(
        event_id: ClientChronicleEvent::SOCIAL_LINKED,
        subject_id: user.id,
        subject_type: "Client",
      )

      assert_equal user.id, result[:user].id
      assert_equal user.id, audit.actor_id
      assert_equal "social", audit.context["auth_method"]
      assert_equal "google", audit.context["provider"]
      assert_equal "ClientSocialGoogle", audit.context["social_identity_type"]
    end
  end

  test "unlink records user-scoped social unlink audit" do
    apple_status = ClientSocialAppleStatus.find_or_create_by!(id: ClientSocialAppleStatus::ACTIVE)
    ClientSocialApple.create!(
      user: @user,
      uid: "apple-backup-#{SecureRandom.hex(8)}",
      provider: "apple",
      token: "apple-token",
      expires_at: 1.hour.from_now.to_i,
      status_id: apple_status.id,
    )

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SOCIAL_UNLINKED).count }, 1 do
      result = SocialAuthService.unlink(provider: "google", client: @user)

      audit = ClientChronicle.order(created_at: :desc).find_by!(
        event_id: ClientChronicleEvent::SOCIAL_UNLINKED,
        subject_id: @user.id,
        subject_type: "Client",
      )

      assert result[:success]
      assert_equal @user.id, audit.actor_id
      assert_equal "social", audit.context["auth_method"]
      assert_equal "google", audit.context["provider"]
      assert_equal "ClientSocialGoogle", audit.context["social_identity_type"]
    end
  end

  test "handle_callback raises error for invalid intent" do
    assert_raises(SocialAuth::UnauthorizedError) do
      SocialAuthService.handle_callback(
        auth_hash: @auth_hash,
        current_client: nil,
        intent: "invalid",
      )
    end
  end

  test "unlink google identity" do
    # Client now has 2 login methods: Google + Email (set up in setup)
    # login_methods_remaining? returns true without stubbing
    result = SocialAuthService.unlink(provider: "google", client: @user)

    assert result[:success]
    assert_equal "google", result[:provider]
    assert_not ClientSocialGoogle.exists?(@identity.id)
  end
end
