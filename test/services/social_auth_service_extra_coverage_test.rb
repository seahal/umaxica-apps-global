# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthServiceExtraCoverageTest < ActiveSupport::TestCase
  setup do
    @user = Client.create!(status_id: ClientStatus::ACTIVE)
    @auth_hash = auth_hash_for("google-123")

    # Ensure necessary statuses exist
    ClientStatus.find_or_create_by!(id: ClientStatus::ACTIVE)
    ClientStatus.find_or_create_by!(id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    ClientSocialGoogleStatus.find_or_create_by!(id: ClientSocialGoogleStatus::ACTIVE)
    ClientSocialGoogleStatus.find_or_create_by!(id: ClientSocialGoogleStatus::REVOKED)
  end

  test "extract_uid falls back to raw_info then id_info" do
    raw_info_service = SocialAuthService.new(
      auth_hash: { "provider" => "apple", "extra" => { "raw_info" => { "sub" => "raw-sub" } } },
      current_client: nil,
      intent: "login",
    )
    id_info_service = SocialAuthService.new(
      auth_hash: { "provider" => "apple", "extra" => { "id_info" => { "sub" => "id-info-sub" } } },
      current_client: nil,
      intent: "login",
    )

    assert_equal "raw-sub", raw_info_service.send(:extract_uid)
    assert_equal "id-info-sub", id_info_service.send(:extract_uid)
  end

  test "extract_uid does not fall back to unsigned id_token" do
    # The strategy is responsible for verifying the id_token signature and
    # populating raw_info/id_info. We must never trust an unsigned id_token
    # to derive uid because a forged token would silently bind to any sub.
    header = Base64.urlsafe_encode64({ alg: "RS256", typ: "JWT" }.to_json, padding: false)
    payload = Base64.urlsafe_encode64({ sub: "forged-sub" }.to_json, padding: false)
    service = SocialAuthService.new(
      auth_hash: { "provider" => "apple", "credentials" => { "id_token" => "#{header}.#{payload}.sig" } },
      current_client: nil,
      intent: "login",
    )

    assert_raises(SocialAuth::ProviderError) do
      service.send(:extract_uid)
    end
  end

  test "handle_login attaches orphaned identity to a new user" do
    identity = ClientSocialGoogle.create!(
      uid: "orphan-google",
      provider: "google",
      user: @user,
      status_id: ClientSocialGoogleStatus::ACTIVE,
      token: "old-token",
      token_expires_at: 1.day.from_now.to_i,
    )
    identity.define_singleton_method(:user) { nil }
    auth_hash = auth_hash_for("orphan-google")

    ClientSocialGoogle.stub(:find_by, identity) do
      result = SocialAuthService.handle_callback(auth_hash: auth_hash, current_client: nil, intent: "login")

      assert_predicate result[:user], :persisted?
      assert_equal result[:user].id, identity.reload.user_id
      assert result[:existing_account]
    end
  end

  test "handle_link reactivates an existing identity for current user" do
    identity = ClientSocialGoogle.create!(
      uid: "existing-for-user",
      provider: "google",
      user: @user,
      status_id: ClientSocialGoogleStatus::REVOKED,
      token: "old-token",
      token_expires_at: 1.day.from_now.to_i,
    )
    auth_hash = auth_hash_for("existing-for-user")

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SOCIAL_LINKED).count }, 1 do
      result = SocialAuthService.handle_callback(auth_hash: auth_hash, current_client: @user, intent: "link")

      assert_equal @user.id, result[:user].id
      assert_equal ClientSocialGoogleStatus::ACTIVE, identity.reload.status_id
    end
  end

  test "handle_link updates identity that already belongs to current user" do
    identity = ClientSocialGoogle.create!(
      uid: "same-user-link",
      provider: "google",
      user: @user,
      status_id: ClientSocialGoogleStatus::ACTIVE,
      token: "old-token",
      token_expires_at: 1.day.from_now.to_i,
    )
    auth_hash = auth_hash_for("same-user-link")
    service = SocialAuthService.new(auth_hash: auth_hash, current_client: @user, intent: "link")
    service.define_singleton_method(:identity_for_user) { |_identity_class, _provider| nil }

    result = service.handle_callback

    assert_equal @user.id, result[:user].id
    assert_equal identity.id, result[:identity].id
  end

  test "step_up intent is rejected for social auth" do
    ClientSocialGoogle.create!(
      uid: "step-up-forbidden-google",
      provider: "google",
      user: @user,
      status_id: ClientSocialGoogleStatus::ACTIVE,
      token: "old-token",
      token_expires_at: 1.day.from_now.to_i,
    )
    auth_hash = auth_hash_for("step-up-forbidden-google")

    assert_raises(SocialAuth::UnauthorizedError) do
      SocialAuthService.handle_callback(auth_hash: auth_hash, current_client: @user, intent: "step_up")
    end

    assert_nil @user.reload.last_step_up_at
  end

  test "handle_login race condition" do
    service = SocialAuthService.new(auth_hash: @auth_hash, current_client: nil, intent: "login")

    # Mock find_by to return nil first, then raise RecordNotUnique on user save
    ClientSocialGoogle.stub(:find_by, nil) do
      user_mock = Client.new
      user_mock.define_singleton_method(:save!) { raise ActiveRecord::RecordNotUnique, "identity conflict" }

      Client.stub(:new, user_mock) do
        assert_raises(SocialAuth::ConflictError) do
          service.handle_callback
        end
      end
    end
  end

  test "handle_link when already linked to another user" do
    other_user = Client.create!(status_id: ClientStatus::ACTIVE)
    ClientSocialGoogle.create!(
      uid: "google-123", provider: "google", user: other_user,
      status_id: ClientSocialGoogleStatus::ACTIVE,
      token: "t", token_expires_at: 1.day.from_now.to_i,
    )

    service = SocialAuthService.new(auth_hash: @auth_hash, current_client: @user, intent: "link")

    assert_raises(SocialAuth::ConflictError) do
      service.handle_callback
    end
  end

  test "step_up intent is rejected before identity matching" do
    other_user = Client.create!(status_id: ClientStatus::ACTIVE)
    ClientSocialGoogle.create!(
      uid: "google-123", provider: "google", user: other_user,
      status_id: ClientSocialGoogleStatus::ACTIVE,
      token: "t", token_expires_at: 1.day.from_now.to_i,
    )

    service = SocialAuthService.new(auth_hash: @auth_hash, current_client: @user, intent: "step_up")

    assert_raises(SocialAuth::UnauthorizedError) do
      service.handle_callback
    end
  end

  test "unlink last identity fails" do
    ClientSocialGoogle.create!(
      uid: "google-123", provider: "google", user: @user,
      status_id: ClientSocialGoogleStatus::ACTIVE,
      token: "t", token_expires_at: 1.day.from_now.to_i,
    )
    # Ensure social_unlink_methods_remaining? returns false
    @user.define_singleton_method(:social_unlink_methods_remaining?) { |**| false }

    service = SocialAuthService.new(auth_hash: nil, current_client: @user, intent: nil)
    assert_raises(SocialAuth::LastIdentityError) do
      service.unlink("google")
    end
  end

  test "unlink removes inactive legacy identity" do
    identity = ClientSocialGoogle.create!(
      uid: "google-123", provider: "google", user: @user,
      status_id: ClientSocialGoogleStatus::REVOKED,
      token: "t", token_expires_at: 1.day.from_now.to_i,
    )

    service = SocialAuthService.new(auth_hash: nil, current_client: @user, intent: nil)
    result = service.unlink("google")

    assert result[:success]
    assert_not ClientSocialGoogle.exists?(identity.id)
  end

  test "ensure_user_status fallback" do
    user = Client.new
    handler = login_handler
    calls = []

    handler.define_singleton_method(:ensure_reference_record!) do |model, id, code|
      calls << [model, id, code]
      Struct.new(:id).new(id)
    end

    handler.send(:ensure_user_status, user)

    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, user.status_id
    assert_equal [[ClientStatus, ClientStatus::UNVERIFIED_WITH_SIGN_UP, "UNVERIFIED_WITH_SIGN_UP"]], calls
  end

  test "ensure_identity_status creates active provider status" do
    service = SocialAuthService.new(auth_hash: @auth_hash, current_client: nil, intent: "login")
    calls = []

    service.define_singleton_method(:ensure_reference_record!) do |model, id, code|
      calls << [model, id, code]
    end

    service.send(:ensure_identity_status!, ClientSocialGoogle)

    assert_equal [[ClientSocialGoogleStatus, ClientSocialGoogleStatus::ACTIVE, "ACTIVE"]], calls
  end

  test "ensure_user_visibility creates default visibility" do
    user = Client.new
    handler = login_handler
    calls = []

    handler.define_singleton_method(:ensure_reference_record!) do |model, id, code|
      calls << [model, id, code]
      Struct.new(:id).new(id)
    end

    handler.send(:ensure_user_visibility, user)

    assert_equal ClientVisibility::STAFF, user.visibility_id
    assert_equal [[ClientVisibility, ClientVisibility::STAFF, "STAFF"]], calls
  end

  test "persist_user! logs and raises on invalid record" do
    user = Client.new # invalid without status_id
    # Ensure it's invalid by mocking save! to raise
    user.define_singleton_method(:save!) { raise ActiveRecord::RecordInvalid.new(self) }

    assert_raises(SocialAuth::ProviderError) do
      login_handler.send(:persist_user!, user, context: "test")
    end
  end

  private

  def login_handler
    SocialAuth::LoginHandler.new(
      auth_hash: @auth_hash,
      identity_class: ClientSocialGoogle,
      provider: "google",
      uid: "google-123",
    )
  end

  def auth_hash_for(uid)
    Struct.new(:provider, :uid, :credentials, :info).new(
      "google",
      uid,
      Struct.new(:token, :refresh_token, :expires_at).new("token", "refresh", 1.hour.from_now.to_i),
      Struct.new(:email).new("test@example.com"),
    )
  end
end
