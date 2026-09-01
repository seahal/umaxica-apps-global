# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

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

  test "current inventory actor prefers an operator, then a visitor, then a client" do
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
    visitor_harness = VisitorActorHarness.new
    visitor_harness.current_visitor = Visitor.new
    operator_harness = OperatorActorHarness.new
    operator_harness.current_operator = operator

    assert_equal operator, operator_harness.send(:current_inventory_actor)
    assert_instance_of Visitor, visitor_harness.send(:current_inventory_actor)
  end

  test "current inventory actor falls back to Actor.actor unless that actor is unauthenticated" do
    authenticated = Object.new
    unauthenticated = Object.new
    unauthenticated.define_singleton_method(:unauthenticated?) { true }

    Actor.stub(:actor, authenticated) do
      assert_equal authenticated, EmptyActorHarness.new.send(:current_inventory_actor)
    end
    Actor.stub(:actor, unauthenticated) do
      assert_nil EmptyActorHarness.new.send(:current_inventory_actor)
    end
  end

  class OperatorActorHarness
    include AuthenticationCredentialInventoryReader

    attr_accessor :current_operator
  end

  class VisitorActorHarness
    include AuthenticationCredentialInventoryReader

    attr_accessor :current_visitor
  end

  class EmptyActorHarness
    include AuthenticationCredentialInventoryReader
  end
end
