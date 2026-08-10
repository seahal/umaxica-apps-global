# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class SocialAuthLoginHandlerTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  FakeRepository =
    Struct.new(:identity, :raise_error, keyword_init: true) do
      def find_by_subject(*)
        raise raise_error if raise_error

        identity
      end

      def refresh_credentials!(*)
        identity
      end
    end

  test "authenticates an existing identity linked to a user" do
    client = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: "sah_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    identity = create_active_external_identity(
      client: client,
      provider: "google",
      subject: "social-auth-handler-existing",
    )
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: identity.subject,
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )
    repository = ExternalAuthentication::ClientExternalIdentityRepositoryAdapter.new(provider: "google")

    result = SocialAuthLoginHandler.call(
      principal: principal,
      credential_candidate: nil,
      repository: repository,
      provider: principal.provider,
      uid: principal.subject,
    )

    assert_equal client, result[:user]
    assert_equal identity, result[:identity]
    assert_equal({ user_id: client.id }, result[:jwt_payload])
    assert_not result[:step_up_authenticated]
    assert result[:existing_account]
    assert_not result.key?(:pending_social_signup)
  end

  test "returns pending social signup when the identity is unknown" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "social-auth-handler-unknown",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )
    repository = FakeRepository.new(identity: nil)

    result = SocialAuthLoginHandler.call(
      principal: principal,
      credential_candidate: nil,
      repository: repository,
      provider: principal.provider,
      uid: principal.subject,
    )

    assert result[:pending_social_signup]
    assert_nil result[:user]
    assert_nil result[:identity]
    assert_equal({}.freeze, result[:jwt_payload])
    assert_not result[:existing_account]
    assert_equal "google", result[:provider]
    assert_equal principal.subject, result[:uid]
  end

  test "returns pending social signup when the identity is not linked to a user" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "social-auth-handler-orphaned",
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )
    orphaned_identity = Struct.new(:user).new(nil)
    repository = FakeRepository.new(identity: orphaned_identity)

    result = SocialAuthLoginHandler.call(
      principal: principal,
      credential_candidate: nil,
      repository: repository,
      provider: principal.provider,
      uid: principal.subject,
    )

    assert result[:pending_social_signup]
    assert_nil result[:user]
    assert_nil result[:identity]
  end

  test "raises a conflict error when a race condition occurs" do
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: "social-auth-handler-conflict",
      issuer: "https://accounts.google.com",
      audience: "google-test-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )
    repository = FakeRepository.new(
      identity: nil,
      raise_error: ActiveRecord::RecordNotUnique.new("duplicate key value"),
    )

    error =
      assert_raises(SocialAuth::ConflictError) do
        SocialAuthLoginHandler.call(
          principal: principal,
          credential_candidate: nil,
          repository: repository,
          provider: principal.provider,
          uid: principal.subject,
        )
      end

    assert_equal "errors.social_auth.identity_conflict", error.i18n_key
  end

  test "creates a user for an orphaned identity" do
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientMfaLevel.ensure_defaults!
    ClientMfaStatus.ensure_defaults!

    identity = Struct.new(:user, :user_id, :id) do
      def update!(attributes)
        attributes.each { |key, value| public_send("#{key}=", value) }
      end
    end.new(nil, nil, 1)
    repository = Struct.new(:assigned) do
      def assign_to_user(identity, user)
        identity.user = user
        assigned << user
      end
    end.new([])
    handler = SocialAuthLoginHandler.new(
      principal: nil,
      credential_candidate: nil,
      repository: repository,
      provider: "google",
      uid: "orphaned-subject",
      sign_up_entry: false,
    )

    user = handler.send(:create_user_for_identity, identity)

    assert_predicate user, :persisted?
    assert_equal user, identity.user
    assert_equal [user], repository.assigned
  end

  test "builds a login user with default reference records" do
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientMfaLevel.ensure_defaults!
    ClientMfaStatus.ensure_defaults!

    handler = SocialAuthLoginHandler.new(
      principal: nil,
      credential_candidate: nil,
      repository: nil,
      provider: "google",
      uid: "subject",
      sign_up_entry: false,
    )
    user = handler.send(:build_login_user)

    assert_predicate user.status_id, :present?
    assert_predicate user.visibility_id, :present?
    assert_predicate user.mfa_level_id, :present?
    assert_predicate user.mfa_status_id, :present?
  end

  test "reference record helpers return nil for blank ids" do
    handler = SocialAuthLoginHandler.new(
      principal: nil,
      credential_candidate: nil,
      repository: nil,
      provider: "google",
      uid: "subject",
      sign_up_entry: false,
    )

    assert_nil handler.send(:ensure_user_visibility_record, nil, "STAFF")
    assert_nil handler.send(:ensure_user_mfa_level_record, nil)
    assert_nil handler.send(:ensure_user_mfa_status_record, nil)
  end

  test "logs when required reference records cannot be resolved" do
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientMfaLevel.ensure_defaults!
    ClientMfaStatus.ensure_defaults!

    handler = SocialAuthLoginHandler.new(
      principal: nil,
      credential_candidate: nil,
      repository: nil,
      provider: "google",
      uid: "subject",
      sign_up_entry: false,
    )
    user = Client.new

    handler.stub(:ensure_user_status_record, nil) do
      ClientStatus.stub(:first, nil) do
        handler.send(:ensure_user_status, user)
      end
    end

    handler.stub(:ensure_user_visibility_record, nil) do
      ClientVisibility.stub(:first, nil) do
        handler.send(:ensure_user_visibility, user)
      end
    end

    handler.stub(:ensure_user_mfa_level_record, nil) do
      ClientMfaLevel.stub(:first, nil) do
        handler.send(:ensure_user_mfa_level, user)
      end
    end

    handler.stub(:ensure_user_mfa_status_record, nil) do
      ClientMfaStatus.stub(:first, nil) do
        handler.send(:ensure_user_mfa_status, user)
      end
    end

    assert_kind_of Client, user
  end

  test "returns nil and logs when reference record creation fails" do
    ClientStatus.ensure_defaults!

    handler = SocialAuthLoginHandler.new(
      principal: nil,
      credential_candidate: nil,
      repository: nil,
      provider: "google",
      uid: "subject",
      sign_up_entry: false,
    )

    ClientStatus.stub(:find_or_create_by!, ->(*) { raise ActiveRecord::StatementInvalid.new("boom") }) do
      assert_nil handler.send(:ensure_user_status_record, ClientStatus::UNVERIFIED_WITH_SIGN_UP, "UNVERIFIED_WITH_SIGN_UP")
    end
  end

  test "raises provider error when user persistence fails" do
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    existing = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    invalid_user = Client.new(
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
      public_id: existing.public_id,
    )
    handler = SocialAuthLoginHandler.new(
      principal: nil,
      credential_candidate: nil,
      repository: nil,
      provider: "google",
      uid: "subject",
      sign_up_entry: false,
    )

    error =
      assert_raises(SocialAuth::ProviderError) do
        handler.send(:persist_user!, invalid_user, context: "test")
      end

    assert_equal "errors.social_auth.provider_error", error.i18n_key
  end

  test "creates social signup audit for google and apple" do
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientChronicleEvent.ensure_defaults!
    ClientChronicleLevel.ensure_defaults!

    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    google_handler = SocialAuthLoginHandler.new(
      principal: nil,
      credential_candidate: nil,
      repository: nil,
      provider: "google",
      uid: "subject",
      sign_up_entry: false,
    )

    assert_difference -> { ClientChronicle.count }, 1 do
      google_handler.send(:create_social_signup_audit, user)
    end

    apple_handler = SocialAuthLoginHandler.new(
      principal: nil,
      credential_candidate: nil,
      repository: nil,
      provider: "apple",
      uid: "subject",
      sign_up_entry: false,
    )

    assert_difference -> { ClientChronicle.count }, 1 do
      apple_handler.send(:create_social_signup_audit, user)
    end
  end

  test "returns nil event id for unknown providers" do
    handler = SocialAuthLoginHandler.new(
      principal: nil,
      credential_candidate: nil,
      repository: nil,
      provider: "unknown",
      uid: "subject",
      sign_up_entry: false,
    )

    assert_nil handler.send(:social_signup_event_id)
  end

  test "builds a result with expected keys" do
    user = Client.new(id: 1)
    identity = Struct.new(:id).new(2)
    handler = SocialAuthLoginHandler.new(
      principal: nil,
      credential_candidate: nil,
      repository: nil,
      provider: "google",
      uid: "subject",
      sign_up_entry: false,
    )
    result = handler.send(:build_result, user, identity, existing_account: true)

    assert_equal user, result[:user]
    assert_equal identity, result[:identity]
    assert_equal({ user_id: 1 }, result[:jwt_payload])
    assert result[:existing_account]
    assert_not result[:step_up_authenticated]
  end
end
