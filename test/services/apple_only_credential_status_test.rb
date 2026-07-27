# frozen_string_literal: true

require "test_helper"

class AppleOnlyCredentialStatusTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_apple_identity_statuses, :client_google_identity_statuses

  test "identifies an active Apple identity as the only AAL1 credential" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "n#{SecureRandom.hex(8)}")
    ClientAppleIdentity.create!(
      user: client,
      provider: "apple",
      uid: "apple-only-warning-#{SecureRandom.hex(8)}",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "",
      token_expires_at: 0,
      status_id: ClientAppleIdentityStatus::ACTIVE,
    )

    assert AppleOnlyCredentialStatus.call(client)
  end

  test "does not warn when Google is also an active AAL1 credential" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "n#{SecureRandom.hex(8)}")
    ClientAppleIdentity.create!(
      user: client,
      provider: "apple",
      uid: "apple-warning-#{SecureRandom.hex(8)}",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "",
      token_expires_at: 0,
      status_id: ClientAppleIdentityStatus::ACTIVE,
    )
    ClientGoogleIdentity.create!(
      user: client,
      provider: "google_app",
      uid: "google-warning-#{SecureRandom.hex(8)}",
      token: ExternalAuthentication::LegacyIdentityCredentialAttributes::NOT_STORED,
      refresh_token: "",
      token_expires_at: 0,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )

    assert_not AppleOnlyCredentialStatus.call(client)
  end
end
