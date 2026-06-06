# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationCredentialInventoryReaderTest < ActiveSupport::TestCase
  class Harness
    include AuthenticationCredentialInventoryReader

    attr_accessor :current_client
  end

  test "controller concern reads the shared credential inventory service" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    client.client_emails.create!(
      address: "inventory-reader@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    harness = Harness.new
    harness.current_client = client

    inventory = harness.send(:current_credential_inventory)

    assert_instance_of AuthenticationCredentialInventory::Result, inventory
    assert_equal AuthenticationCredentialInventory.call(client, reload: true).aal2_methods, inventory.aal2_methods
  end

  test "controller concern supports excluding a candidate credential" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    email = client.client_emails.create!(
      address: "inventory-reader-excluding@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    harness = Harness.new
    harness.current_client = client

    inventory = harness.send(:current_credential_inventory, excluding: email)

    assert_empty inventory.aal1_methods
    assert_empty inventory.aal2_methods
    assert_empty inventory.contact_identifiers
  end
end
