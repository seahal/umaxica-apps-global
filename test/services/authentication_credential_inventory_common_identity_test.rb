# frozen_string_literal: true

require "test_helper"

class AuthenticationCredentialInventoryCommonIdentityTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "uses active common social identities after the repository cutover" do
    client = Client.create!(status_id: ClientStatus::ACTIVE, public_id: "n#{SecureRandom.hex(8)}")
    ClientExternalIdentity.create!(
      client: client,
      provider: "apple",
      issuer: "https://appleid.apple.com",
      subject: "common-inventory-#{SecureRandom.hex(8)}",
      audience: "apple-client-id",
      verification_authority: "test",
      verified_at: Time.current,
    )

    inventory = AuthenticationCredentialInventory.call(client)

    assert_equal [:apple], inventory.aal1_methods
  end
end
