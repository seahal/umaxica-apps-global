# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthServiceExtraCoverageTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(status_id: UserStatus::ACTIVE)
    @auth_hash = {
      "provider" => "google",
      "uid" => "google-123",
      "info" => { "email" => "test@example.com" },
      "credentials" => { "token" => "token", "expires_at" => Time.current.to_i + 3600 },
    }.with_indifferent_access

    # Ensure necessary statuses exist
    UserStatus.find_or_create_by!(id: UserStatus::ACTIVE)
    UserStatus.find_or_create_by!(id: UserStatus::UNVERIFIED_WITH_SIGN_UP)
    UserSocialGoogleStatus.find_or_create_by!(id: UserSocialGoogleStatus::ACTIVE)
    UserSocialGoogleStatus.find_or_create_by!(id: UserSocialGoogleStatus::REVOKED)
  end

  test "extract_uid_from_id_token rejects disallowed algorithms" do
    # alg: none forgery attempt
    header = Base64.urlsafe_encode64({ alg: "none", typ: "JWT" }.to_json).gsub("=", "")
    id_token = "#{header}.payload.signature"
    auth_hash = { "provider" => "apple", "credentials" => { "id_token" => id_token } }.with_indifferent_access

    service = SocialAuthService.new(auth_hash: auth_hash, current_user: nil, intent: "login")

    assert_nil service.send(:extract_uid_from_id_token)
  end

  test "handle_login race condition" do
    service = SocialAuthService.new(auth_hash: @auth_hash, current_user: nil, intent: "login")

    # Mock find_by to return nil first, then raise RecordNotUnique on user save
    UserSocialGoogle.stub(:find_by, nil) do
      user_mock = User.new
      user_mock.define_singleton_method(:save!) { raise ActiveRecord::RecordNotUnique, "identity conflict" }

      User.stub(:new, user_mock) do
        assert_raises(SocialAuth::ConflictError) do
          service.handle_callback
        end
      end
    end
  end

  test "handle_link when already linked to another user" do
    other_user = User.create!(status_id: UserStatus::ACTIVE)
    UserSocialGoogle.create!(
      uid: "google-123", provider: "google", user: other_user,
      status_id: UserSocialGoogleStatus::ACTIVE,
      token: "t", token_expires_at: 1.day.from_now.to_i,
    )

    service = SocialAuthService.new(auth_hash: @auth_hash, current_user: @user, intent: "link")

    assert_raises(SocialAuth::ConflictError) do
      service.handle_callback
    end
  end

  test "handle_reauth mismatch" do
    other_user = User.create!(status_id: UserStatus::ACTIVE)
    UserSocialGoogle.create!(
      uid: "google-123", provider: "google", user: other_user,
      status_id: UserSocialGoogleStatus::ACTIVE,
      token: "t", token_expires_at: 1.day.from_now.to_i,
    )

    service = SocialAuthService.new(auth_hash: @auth_hash, current_user: @user, intent: "reauth")

    assert_raises(SocialAuth::UnauthorizedError) do
      service.handle_callback
    end
  end

  test "unlink last identity fails" do
    UserSocialGoogle.create!(
      uid: "google-123", provider: "google", user: @user,
      status_id: UserSocialGoogleStatus::ACTIVE,
      token: "t", token_expires_at: 1.day.from_now.to_i,
    )
    # Ensure login_methods_remaining? returns false
    @user.define_singleton_method(:login_methods_remaining?) { |**| false }

    service = SocialAuthService.new(auth_hash: nil, current_user: @user, intent: nil)
    assert_raises(SocialAuth::LastIdentityError) do
      service.unlink("google")
    end
  end

  test "unlink already unlinked" do
    UserSocialGoogle.create!(
      uid: "google-123", provider: "google", user: @user,
      status_id: UserSocialGoogleStatus::REVOKED,
      token: "t", token_expires_at: 1.day.from_now.to_i,
    )

    service = SocialAuthService.new(auth_hash: nil, current_user: @user, intent: nil)
    result = service.unlink("google")

    assert result[:already_unlinked]
  end

  test "ensure_user_status fallback" do
    user = User.new
    # Mock UserStatus.exists? to fail
    UserStatus.stub(:exists?, false) do
      UserStatus.stub(:first, Struct.new(:id).new(999)) do
        service = SocialAuthService.new(auth_hash: @auth_hash, current_user: nil, intent: "login")
        service.send(:ensure_user_status, user)

        assert_equal 999, user.status_id
      end
    end
  end

  test "persist_user! logs and raises on invalid record" do
    user = User.new # invalid without status_id
    # Ensure it's invalid by mocking save! to raise
    user.define_singleton_method(:save!) { raise ActiveRecord::RecordInvalid.new(self) }

    service = SocialAuthService.new(auth_hash: @auth_hash, current_user: nil, intent: "login")

    assert_raises(SocialAuth::ProviderError) do
      service.send(:persist_user!, user, context: "test")
    end
  end
end
