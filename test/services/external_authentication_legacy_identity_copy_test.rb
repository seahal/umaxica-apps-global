# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationLegacyIdentityCopyTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_apple_identity_statuses, :client_google_identity_statuses

  test "copies active legacy Apple and Google bindings once into the common schema" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "m#{SecureRandom.hex(8)}")
    ClientAppleIdentity.create!(
      user: client,
      provider: "apple",
      uid: "migration-apple-subject",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "migration-apple-refresh",
      token_expires_at: 0,
      status_id: ClientAppleIdentityStatus::ACTIVE,
    )
    ClientGoogleIdentity.create!(
      user: client,
      provider: "google",
      uid: "migration-google-subject",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "",
      token_expires_at: 0,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )

    report = ExternalAuthenticationLegacyIdentityCopy.call

    assert_equal 1, report.apple_count
    assert_equal 1, report.google_count
    assert_equal 2, report.copied_count
    apple = ClientExternalIdentity.find_by!(provider: "apple", subject: "migration-apple-subject")
    google = ClientExternalIdentity.find_by!(provider: "google", subject: "migration-google-subject")

    assert_equal client, apple.client
    assert_equal client, google.client
    assert_equal "migration-apple-refresh", apple.client_apple_identity_credential.refresh_token
    assert_nil google.client_apple_identity_credential

    verification = ExternalAuthenticationLegacyIdentityCopy.verify!

    assert_equal report, verification
  end

  test "preflight is read-only and reports source counts" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "m#{SecureRandom.hex(8)}")
    ClientGoogleIdentity.create!(
      user: client,
      provider: "google",
      uid: "migration-preflight-subject",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "",
      token_expires_at: 0,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )

    report = ExternalAuthenticationLegacyIdentityCopy.preflight!

    assert_equal 0, report.apple_count
    assert_equal 1, report.google_count
    assert_equal 0, report.copied_count
    assert_equal 0, ClientExternalIdentity.count
  end

  test "refuses a copy when a destination binding already exists" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "m#{SecureRandom.hex(8)}")
    ClientGoogleIdentity.create!(
      user: client,
      provider: "google",
      uid: "migration-existing-source",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "",
      token_expires_at: 0,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    ClientExternalIdentity.create!(
      client: client,
      provider: "apple",
      issuer: "https://appleid.apple.com",
      subject: "existing-destination",
      audience: "apple-client-id",
      verification_authority: "legacy-migration",
      verified_at: Time.current,
    )

    error =
      assert_raises(ExternalAuthenticationLegacyIdentityCopy::PreflightError) do
        ExternalAuthenticationLegacyIdentityCopy.call
      end

    assert_equal :destination_not_empty, error.code
  end

  test "refuses to infer a target state for inactive legacy identities" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "m#{SecureRandom.hex(8)}")
    ClientAppleIdentity.create!(
      user: client,
      provider: "apple",
      uid: "migration-inactive-source",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "",
      token_expires_at: 0,
      status_id: ClientAppleIdentityStatus::REVOKED,
    )

    error =
      assert_raises(ExternalAuthenticationLegacyIdentityCopy::PreflightError) do
        ExternalAuthenticationLegacyIdentityCopy.call
      end

    assert_equal :inactive_legacy_identity, error.code
    assert_equal 0, ClientExternalIdentity.count
  end
end
