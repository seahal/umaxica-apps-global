# typed: false
# frozen_string_literal: true

require "test_helper"

class LegacyIdentityRepositoryAdapterTest < ActiveSupport::TestCase
  fixtures :client_google_identity_statuses, :client_apple_identity_statuses

  test "Google repository finds only the configured provider identity" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "repo_g_#{SecureRandom.hex(4)}")
    identity = ClientGoogleIdentity.create!(
      user: client,
      provider: "google",
      uid: "repository-google-subject",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "",
      token_expires_at: 0,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    repository = ExternalAuthentication::LegacyIdentityRepositoryFactory.build("google")

    assert_equal identity, repository.find_by_subject("repository-google-subject", lock: false)
    assert_equal identity, repository.find_for_user(client)
    assert_nil repository.find_by_subject("missing-subject", lock: false)
    assert_equal ClientGoogleIdentity, repository.model_class
  end

  test "Apple repository builds and refreshes only approved credential fields" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "repo_a_#{SecureRandom.hex(4)}")
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "apple",
      subject: "repository-apple-subject",
      issuer: "https://appleid.apple.com",
      audience: "apple-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-apple/contract",
    )
    candidate = ExternalAuthentication::AppleCredentialCandidate.new(refresh_token: "apple-refresh-one")
    repository = ExternalAuthentication::LegacyIdentityRepositoryFactory.build("apple")

    identity = repository.build_for_user(
      user: client,
      principal: principal,
      credential_candidate: candidate,
    )
    identity.save!
    repository.refresh_credentials!(
      identity,
      principal: principal,
      credential_candidate: ExternalAuthentication::AppleCredentialCandidate.new(
        refresh_token: "apple-refresh-two",
      ),
    )

    assert_equal "repository-apple-subject", identity.reload.uid
    assert_equal ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED, identity.token
    assert_equal "apple-refresh-two", identity.refresh_token
    assert_equal 0, identity.token_expires_at
    assert_predicate identity.last_authenticated_at, :present?
  end

  test "repository factory rejects unsupported providers" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::LegacyIdentityRepositoryFactory.build("github")
    end
  end
end
