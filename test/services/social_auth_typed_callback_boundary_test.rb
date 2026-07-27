# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthTypedCallbackBoundaryTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_google_identity_statuses, :client_apple_identity_statuses

  test "login use case resolves an existing Google identity from a verified principal without provider payload" do
    client = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: "typed_google_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    identity = ClientGoogleIdentity.create!(
      user: client,
      provider: "google",
      uid: "typed-google-subject",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "",
      token_expires_at: 0,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    principal = ExternalAuthentication::VerifiedPrincipal.new(
      provider: "google",
      subject: identity.uid,
      issuer: "https://accounts.google.com",
      audience: "google-client-id",
      verified_at: Time.current,
      verification_authority: "omniauth-google-oauth2/contract",
    )

    result = ExternalAuthenticationLoginUseCase.call(
      principal: principal,
      credential_candidate: nil,
      sign_up_entry: false,
    )

    assert_equal client, result.user
    assert_equal identity, result.identity
    assert_equal ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED, identity.reload.token
    assert_equal "", identity.refresh_token
  end

  test "credential attributes never accept an OmniAuth AuthHash" do
    auth_hash = OmniAuth::AuthHash.new(
      provider: "google",
      uid: "untrusted-subject",
      credentials: { token: "must-not-cross-boundary" },
    )

    assert_raises(ArgumentError) do
      ExternalAuthentication::LegacyIdentityCredentialAttributes.new(
        provider: "google",
        credential_candidate: auth_hash,
      )
    end
  end

  test "Apple credential attributes retain only the refresh token" do
    candidate = ExternalAuthentication::AppleCredentialCandidate.new(refresh_token: "apple-refresh-token")

    attributes = ExternalAuthentication::LegacyIdentityCredentialAttributes.new(
      provider: "apple",
      credential_candidate: candidate,
    ).to_h

    assert_equal ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED, attributes.fetch(:token)
    assert_equal "apple-refresh-token", attributes.fetch(:refresh_token)
    assert_equal 0, attributes.fetch(:token_expires_at)
    assert_not_includes attributes.values, "apple-access-token"
  end

  test "Apple identity refresh token is encrypted at rest by Active Record Encryption" do
    client = Client.create!(
      status_id: ClientStatus::ACTIVE,
      public_id: "enc_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    identity = ClientAppleIdentity.create!(
      user: client,
      provider: "apple",
      uid: "encrypted-apple-subject",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "plaintext-must-not-be-stored",
      token_expires_at: 0,
      status_id: ClientAppleIdentityStatus::ACTIVE,
    )

    stored_value = ClientAppleIdentity.connection.select_value(
      ClientAppleIdentity.where(id: identity.id).select(:refresh_token).to_sql,
    )

    assert_equal "plaintext-must-not-be-stored", identity.reload.refresh_token
    assert_not_equal "plaintext-must-not-be-stored", stored_value
    assert_not_includes stored_value, "plaintext-must-not-be-stored"
  end
end
