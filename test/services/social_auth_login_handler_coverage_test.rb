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
    Client.create!(status_id: ClientStatus::ACTIVE)
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

  test "build_login_user wires reference records through the fallback helpers" do
    handler = SocialAuthLoginHandler.new(
      auth_hash: @auth_hash,
      identity_class: ClientGoogleIdentity,
      provider: "google",
      uid: "google-build-user",
    )

    calls = []
    handler.define_singleton_method(:ensure_user_status) { |user| calls << [:status, user] }
    handler.define_singleton_method(:ensure_user_visibility) { |user| calls << [:visibility, user] }
    handler.define_singleton_method(:ensure_user_mfa_level) { |user| calls << [:mfa_level, user] }
    handler.define_singleton_method(:ensure_user_mfa_status) { |user| calls << [:mfa_status, user] }

    user = handler.send(:build_login_user)

    assert_instance_of Client, user
    assert_equal %i(status visibility mfa_level mfa_status), calls.map(&:first)
  end

  test "create_user_for_identity persists and links the new identity" do
    handler = SocialAuthLoginHandler.new(
      auth_hash: @auth_hash,
      identity_class: ClientGoogleIdentity,
      provider: "google",
      uid: "google-create-user",
    )
    user = Client.new
    identity = ClientGoogleIdentity.new(uid: "google-create-user", provider: "google")
    updates = []

    handler.define_singleton_method(:build_login_user) { user }
    handler.define_singleton_method(:persist_user!) { |_user, context:| updates << [:persist, context] }
    handler.define_singleton_method(:assign_identity_to_user) do |assigned_user, assigned_identity|
      updates << [:assign, assigned_user, assigned_identity]
    end
    identity.define_singleton_method(:update!) { |attrs| updates << [:update, attrs] }

    result = handler.send(:create_user_for_identity, identity)

    assert_same user, result
    assert_equal [[:persist, "login_orphaned_identity"], [:assign, user, identity], [:update, { user_id: user.id }]], updates
  end

  test "reference helpers create missing records and swallow active record failures" do
    handler = SocialAuthLoginHandler.new(
      auth_hash: @auth_hash,
      identity_class: ClientGoogleIdentity,
      provider: "google",
      uid: "google-ref-helper",
    )

    model = Class.new do
      def self.column_names = ["code"]

      def self.name = "FakeReferenceModel"

      def self.find_or_create_by!(id:)
        raise ActiveRecord::RecordNotUnique, "duplicate"
      end
    end

    result = handler.send(:ensure_reference_record!, model, 123, "ABC")

    assert_nil result
  end

  test "create_user_social_audit! and social_signup_event_id handle provider branches" do
    handler = SocialAuthLoginHandler.new(
      auth_hash: @auth_hash,
      identity_class: ClientGoogleIdentity,
      provider: "google",
      uid: "google-audit",
    )
    user = Client.new(id: 123)
    events = []

    ChronicleRecord.stub(:connected_to, lambda { |**_kwargs, &block| block.call }) do
      ClientChronicleEvent.stub(:find_or_create_by!, lambda { |**_kwargs| true }) do
        ClientChronicleLevel.stub(:find_or_create_by!, lambda { |**_kwargs| true }) do
          ClientChronicle.stub(:create!, lambda { |**kwargs| events << kwargs }) do
            handler.send(:create_social_signup_audit, user)
          end
        end
      end
    end

    assert_equal ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE, handler.send(:social_signup_event_id)
    assert_equal 1, events.size
    assert_equal user.id, events.first[:actor_id]
    assert_equal user.id.to_s, events.first[:subject_id]
  end

  test "build_identity_for_user copies credential payloads and assign_identity_to_user only links supported models" do
    handler = SocialAuthLoginHandler.new(
      auth_hash: {
        "provider" => "google",
        "uid" => "google-identity",
        "credentials" => {
          "token" => "token-1",
          "refresh_token" => "refresh-1",
          "expires_at" => 123,
        },
      },
      identity_class: ClientGoogleIdentity,
      provider: "google",
      uid: "google-identity",
    )
    user = Client.new(id: 77)

    identity = handler.send(:build_identity_for_user, user)

    assert_equal "google-identity", identity.uid
    assert_equal "token-1", identity.token
    assert_equal "refresh-1", identity.refresh_token
    assert_equal 123, identity.expires_at
    assert_equal user.id, identity.user_id

    other_handler = SocialAuthLoginHandler.new(
      auth_hash: @auth_hash,
      identity_class: Class.new do
        def self.name = "OtherIdentity"

        attr_accessor :user_id
      end,
      provider: "google",
      uid: "google-identity",
    )
    other_identity = Struct.new(:user_id).new(nil)
    other_handler.send(:assign_identity_to_user, user, other_identity)
    assert_nil other_identity.user_id
  end
end
