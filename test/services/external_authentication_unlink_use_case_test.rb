# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationUnlinkUseCaseTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  fixtures :client_google_identity_statuses, :client_apple_identity_statuses

  test "unlinks an identity and records a typed audited result" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "unlink_uc_#{SecureRandom.hex(4)}")
    identity = ClientGoogleIdentity.create!(
      user: client,
      provider: "google",
      uid: "unlink-use-case-subject",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "",
      token_expires_at: 0,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    client.define_singleton_method(:social_unlink_methods_remaining?) { |**| true }

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::SOCIAL_UNLINKED).count }, 1 do
      result = ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client)

      assert_instance_of ExternalAuthentication::UnlinkResult, result
      assert_equal :unlinked, result.status
      assert_equal "google", result.provider
      assert_not ClientGoogleIdentity.exists?(identity.id)
    end
  end

  test "does not remove the last active authentication method" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "last_uc_#{SecureRandom.hex(4)}")
    identity = ClientGoogleIdentity.create!(
      user: client,
      provider: "google",
      uid: "unlink-last-subject",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "",
      token_expires_at: 0,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    client.define_singleton_method(:social_unlink_methods_remaining?) { |**| false }

    assert_raises(SocialAuth::LastIdentityError) do
      ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client)
    end

    assert ClientGoogleIdentity.exists?(identity.id)
  end

  test "Apple unlink creates a durable encrypted revocation request" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "apple_unlink_#{SecureRandom.hex(4)}")
    identity = ClientAppleIdentity.create!(
      user: client,
      provider: "apple",
      uid: "apple-unlink-subject",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "apple-refresh-token",
      token_expires_at: 0,
      status_id: ClientAppleIdentityStatus::ACTIVE,
    )
    client.define_singleton_method(:social_unlink_methods_remaining?) { |**| true }

    assert_enqueued_with(job: AppleCredentialRevocationJob) do
      ExternalAuthenticationUnlinkUseCase.call(provider: "apple", user: client)
    end

    request = ClientAppleCredentialRevocation.find_by!(client: client)

    assert_equal "unlink", request.reason
    assert_equal "apple-refresh-token", request.refresh_token
    assert_not ClientAppleIdentity.exists?(identity.id)
  end

  test "returns already unlinked when no provider identity exists" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "none_uc_#{SecureRandom.hex(4)}")

    result = ExternalAuthenticationUnlinkUseCase.call(provider: "google", user: client)

    assert_instance_of ExternalAuthentication::UnlinkResult, result
    assert_equal :already_unlinked, result.status
    assert_equal "google", result.provider
  end
end
