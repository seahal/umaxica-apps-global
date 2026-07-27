# frozen_string_literal: true

require "test_helper"

class ClientAppleIdentityCredentialTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "non-deterministically encrypts an Apple refresh token" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "c#{SecureRandom.hex(8)}")
    identity = ClientExternalIdentity.create!(
      client: client,
      provider: "apple",
      issuer: "https://appleid.apple.com",
      subject: "apple-subject-credential",
      audience: "apple-client-id",
      verification_authority: "omniauth-apple/1.4.0",
      verified_at: Time.current,
    )
    credential = ClientAppleIdentityCredential.create!(
      client_external_identity: identity,
      refresh_token: "apple-refresh-token",
    )

    stored_value = ClientAppleIdentityCredential.connection.select_value(
      ClientAppleIdentityCredential.where(id: credential.id).select(:refresh_token).to_sql,
    )

    assert_not_includes stored_value, "apple-refresh-token"
    assert_equal "apple-refresh-token", credential.refresh_token
    assert_predicate credential, :active?
  end

  test "rejects a credential for a non-Apple binding" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "c#{SecureRandom.hex(8)}")
    identity = ClientExternalIdentity.create!(
      client: client,
      provider: "google",
      issuer: "https://accounts.google.com",
      subject: "google-subject-credential",
      audience: "google-client-id",
      verification_authority: "omniauth-google-oauth2/1.2.1",
      verified_at: Time.current,
    )

    credential = ClientAppleIdentityCredential.new(
      client_external_identity: identity,
      refresh_token: "apple-refresh-token",
    )

    assert_not_predicate credential, :valid?
    assert credential.errors.of_kind?(:client_external_identity, :invalid)
  end
end
