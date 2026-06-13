# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthLoginHandlerCoverageTest < ActiveSupport::TestCase
  setup do
    ClientStatus.find_or_create_by!(id: ClientStatus::ACTIVE)
    ClientStatus.find_or_create_by!(id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    ClientGoogleIdentityStatus.find_or_create_by!(id: ClientGoogleIdentityStatus::ACTIVE)
    ClientGoogleIdentityStatus.find_or_create_by!(id: ClientGoogleIdentityStatus::REVOKED)

    @auth_hash =
      OmniAuth::AuthHash.new(
        {
          "provider" => "google",
          "uid" => "google-coverage-uid",
          "credentials" => {
            "token" => "token",
            "refresh_token" => "refresh",
            "expires_at" => 1.hour.from_now.to_i,
          },
        },
      )
  end

  test "call returns pending signup for unknown identity" do
    handler = SocialAuthLoginHandler.new(
      auth_hash: @auth_hash,
      identity_class: ClientGoogleIdentity,
      provider: "google",
      uid: "missing-google-uid",
    )

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        result = handler.call

        assert result[:pending_social_signup]
        assert_nil result[:user]
        assert_nil result[:identity]
      end
    end
  end

  test "call returns login result for existing identity with user" do
    user = Client.create!(status_id: ClientStatus::ACTIVE)
    identity = ClientGoogleIdentity.create!(
      user: user,
      uid: "google-existing-uid",
      provider: "google",
      status_id: ClientGoogleIdentityStatus::ACTIVE,
      token: "old-token",
      token_expires_at: 1.day.from_now.to_i,
    )
    handler = SocialAuthLoginHandler.new(
      auth_hash: @auth_hash,
      identity_class: ClientGoogleIdentity,
      provider: "google",
      uid: identity.uid,
    )

    result = handler.call

    assert_equal user.id, result[:user].id
    assert_equal identity.id, result[:identity].id
    assert_equal user.id, result[:jwt_payload][:user_id]
    assert_not result[:pending_social_signup]
  end

  test "call returns pending signup when an identity exists without a user" do
    user = Client.create!(status_id: ClientStatus::ACTIVE)
    identity = ClientGoogleIdentity.new(
      uid: "google-orphan-uid",
      provider: "google",
      status_id: ClientGoogleIdentityStatus::ACTIVE,
      token: "old-token",
      token_expires_at: 1.day.from_now.to_i,
    )
    handler = SocialAuthLoginHandler.new(
      auth_hash: @auth_hash,
      identity_class: ClientGoogleIdentity,
      provider: "google",
      uid: identity.uid,
    )

    relation = Object.new
    relation.define_singleton_method(:find_by) do |**|
      identity.define_singleton_method(:user) { nil }
      identity.define_singleton_method(:update_from_auth_hash!) { true }
      identity
    end

    ClientGoogleIdentity.stub(:lock, relation) do
      result = handler.call

      assert result[:pending_social_signup]
      assert_nil result[:user]
      assert_nil result[:identity]
    end
  end

  test "call maps duplicate identity creation to conflict error" do
    handler = SocialAuthLoginHandler.new(
      auth_hash: @auth_hash,
      identity_class: ClientGoogleIdentity,
      provider: "google",
      uid: "google-race-uid",
    )

    relation = Object.new
    relation.define_singleton_method(:find_by) do |**|
      raise ActiveRecord::RecordNotUnique, "duplicate"
    end

    ClientGoogleIdentity.stub(:lock, relation) do
      assert_raises(SocialAuth::ConflictError) { handler.call }
    end
  end
end
