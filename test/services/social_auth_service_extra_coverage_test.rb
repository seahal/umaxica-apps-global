# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthServiceExtraCoverageTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(status_id: UserStatus::ACTIVE)
    @auth_hash = auth_hash_for("google-123")

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

  test "extract_uid falls back to raw_info id_info and signed id token" do
    raw_info_service = SocialAuthService.new(
      auth_hash: { "provider" => "apple", "extra" => { "raw_info" => { "sub" => "raw-sub" } } },
      current_user: nil,
      intent: "login",
    )
    id_info_service = SocialAuthService.new(
      auth_hash: { "provider" => "apple", "extra" => { "id_info" => { "sub" => "id-info-sub" } } },
      current_user: nil,
      intent: "login",
    )
    header = Base64.urlsafe_encode64({ alg: "RS256", typ: "JWT" }.to_json, padding: false)
    payload = Base64.urlsafe_encode64({ sub: "token-sub" }.to_json, padding: false)
    token_service = SocialAuthService.new(
      auth_hash: { "provider" => "apple", "credentials" => { "id_token" => "#{header}.#{payload}.sig" } },
      current_user: nil,
      intent: "login",
    )

    assert_equal "raw-sub", raw_info_service.send(:extract_uid)
    assert_equal "id-info-sub", id_info_service.send(:extract_uid)
    assert_equal "token-sub", token_service.send(:extract_uid)
  end

  test "handle_login attaches orphaned identity to a new user" do
    identity = UserSocialGoogle.create!(
      uid: "orphan-google",
      provider: "google",
      user: @user,
      status_id: UserSocialGoogleStatus::ACTIVE,
      token: "old-token",
      token_expires_at: 1.day.from_now.to_i,
    )
    identity.define_singleton_method(:user) { nil }
    auth_hash = auth_hash_for("orphan-google")

    UserSocialGoogle.stub(:find_by, identity) do
      result = SocialAuthService.handle_callback(auth_hash: auth_hash, current_user: nil, intent: "login")

      assert_predicate result[:user], :persisted?
      assert_equal result[:user].id, identity.reload.user_id
      assert result[:existing_account]
    end
  end

  test "handle_link reactivates an existing identity for current user" do
    identity = UserSocialGoogle.create!(
      uid: "existing-for-user",
      provider: "google",
      user: @user,
      status_id: UserSocialGoogleStatus::REVOKED,
      token: "old-token",
      token_expires_at: 1.day.from_now.to_i,
    )
    auth_hash = auth_hash_for("different-provider-uid")

    assert_difference -> { UserChronicle.where(event_id: UserChronicleEvent::SOCIAL_LINKED).count }, 1 do
      result = SocialAuthService.handle_callback(auth_hash: auth_hash, current_user: @user, intent: "link")

      assert_equal @user.id, result[:user].id
      assert_equal UserSocialGoogleStatus::ACTIVE, identity.reload.status_id
    end
  end

  test "handle_link updates identity that already belongs to current user" do
    identity = UserSocialGoogle.create!(
      uid: "same-user-link",
      provider: "google",
      user: @user,
      status_id: UserSocialGoogleStatus::ACTIVE,
      token: "old-token",
      token_expires_at: 1.day.from_now.to_i,
    )
    auth_hash = auth_hash_for("same-user-link")
    service = SocialAuthService.new(auth_hash: auth_hash, current_user: @user, intent: "link")
    service.define_singleton_method(:identity_for_user) { |_identity_class, _provider| nil }

    result = service.handle_callback

    assert_equal @user.id, result[:user].id
    assert_equal identity.id, result[:identity].id
  end

  test "handle_reauth updates last reauth timestamp and returns payload" do
    identity = UserSocialGoogle.create!(
      uid: "reauth-google",
      provider: "google",
      user: @user,
      status_id: UserSocialGoogleStatus::ACTIVE,
      token: "old-token",
      token_expires_at: 1.day.from_now.to_i,
    )
    auth_hash = auth_hash_for("reauth-google")

    result = SocialAuthService.handle_callback(auth_hash: auth_hash, current_user: @user, intent: "reauth")

    assert_equal identity.id, result[:identity].id
    assert result[:reauthenticated]
    assert_predicate @user.reload.last_reauth_at, :present?
    assert_predicate result[:jwt_payload][:reauthenticated_at], :present?
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

  test "unlink removes inactive legacy identity" do
    identity = UserSocialGoogle.create!(
      uid: "google-123", provider: "google", user: @user,
      status_id: UserSocialGoogleStatus::REVOKED,
      token: "t", token_expires_at: 1.day.from_now.to_i,
    )

    service = SocialAuthService.new(auth_hash: nil, current_user: @user, intent: nil)
    result = service.unlink("google")

    assert result[:success]
    assert_not UserSocialGoogle.exists?(identity.id)
  end

  test "ensure_user_status fallback" do
    user = User.new
    service = SocialAuthService.new(auth_hash: @auth_hash, current_user: nil, intent: "login")
    calls = []

    service.define_singleton_method(:ensure_reference_record!) do |model, id, code|
      calls << [model, id, code]
      Struct.new(:id).new(id)
    end

    service.send(:ensure_user_status, user)

    assert_equal UserStatus::UNVERIFIED_WITH_SIGN_UP, user.status_id
    assert_equal [[UserStatus, UserStatus::UNVERIFIED_WITH_SIGN_UP, "UNVERIFIED_WITH_SIGN_UP"]], calls
  end

  test "ensure_identity_status creates active provider status" do
    service = SocialAuthService.new(auth_hash: @auth_hash, current_user: nil, intent: "login")
    calls = []

    service.define_singleton_method(:ensure_reference_record!) do |model, id, code|
      calls << [model, id, code]
    end

    service.send(:ensure_identity_status!, UserSocialGoogle)

    assert_equal [[UserSocialGoogleStatus, UserSocialGoogleStatus::ACTIVE, "ACTIVE"]], calls
  end

  test "ensure_user_visibility creates default visibility" do
    user = User.new
    service = SocialAuthService.new(auth_hash: @auth_hash, current_user: nil, intent: "login")
    calls = []

    service.define_singleton_method(:ensure_reference_record!) do |model, id, code|
      calls << [model, id, code]
      Struct.new(:id).new(id)
    end

    service.send(:ensure_user_visibility, user)

    assert_equal UserVisibility::STAFF, user.visibility_id
    assert_equal [[UserVisibility, UserVisibility::STAFF, "STAFF"]], calls
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

  private

  def auth_hash_for(uid)
    Struct.new(:provider, :uid, :credentials, :info).new(
      "google",
      uid,
      Struct.new(:token, :refresh_token, :expires_at).new("token", "refresh", 1.hour.from_now.to_i),
      Struct.new(:email).new("test@example.com"),
    )
  end
end
