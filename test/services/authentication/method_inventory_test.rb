# typed: false
# frozen_string_literal: true

require "test_helper"

class Authentication::MethodInventoryTest < ActiveSupport::TestCase
  test "client separates login and step-up methods" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    client.client_emails.create!(
      address: "inventory-client@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    client.client_one_time_passwords.create!(
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    inventory = Authentication::MethodInventory.call(client)

    assert_includes inventory.aal1_methods, :email_otp
    assert_includes inventory.step_up_methods, :email_otp
    assert_includes inventory.step_up_methods, :totp
    assert_includes inventory.aal2_methods, :email_otp
    assert_includes inventory.contact_identifiers, :email
    assert_predicate inventory, :aal1_available?
    assert_predicate inventory, :aal2_available?
    assert_predicate inventory, :contactable?
    assert_predicate inventory, :retains_aal1?
    assert_predicate inventory, :retains_aal2?
    assert_predicate inventory, :retains_contactability?
  end

  test "visitor email otp remains a step-up method" do
    ensure_visitor_reference_records!
    visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::BOTH,
    )
    visitor.visitor_emails.create!(
      address: "inventory-visitor@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    inventory = Authentication::MethodInventory.call(visitor)

    assert_includes inventory.aal1_methods, :email_otp
    assert_includes inventory.step_up_methods, :email_otp
    assert_includes inventory.contact_identifiers, :email
  end

  test "operator aal methods are passkey only when only email and passkey exist" do
    staff = Operator.create!(status_id: OperatorIdentityStatus::ACTIVE, visibility_id: OperatorVisibility::BOTH)
    staff.operator_emails.create!(
      address: "inventory-staff@example.com",
      staff_identity_email_status_id: OperatorEmailStatus::ACTIVE,
      otp_counter: "0",
      otp_private_key: "private_key",
    )

    passkey = staff.operator_passkeys.new(
      webauthn_id: "inventory_staff_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      name: "inventory staff passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    passkey.save!(validate: false)

    inventory = Authentication::MethodInventory.call(staff)

    assert_includes inventory.contact_identifiers, :email
    assert_not_includes inventory.aal1_methods, :email_otp
    assert_not_includes inventory.step_up_methods, :email_otp
    assert_equal [:passkey], inventory.aal1_methods
    assert_equal [:passkey], inventory.step_up_methods
  end

  test "excluding removes a credential from aal and contact counts" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    email = client.client_emails.create!(
      address: "inventory-excluding@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    inventory = Authentication::MethodInventory.call(client, excluding: email)

    assert_empty inventory.login_methods
    assert_empty inventory.step_up_methods
    assert_empty inventory.contact_identifiers
    assert_not inventory.aal1_available?
    assert_not inventory.aal2_available?
    assert_not inventory.contactable?
  end

  test "telephone is contact identifier but not aal method" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    client.client_telephones.create!(
      number: "+819011122233",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    inventory = Authentication::CredentialInventory.call(client)

    assert_equal [:telephone], inventory.contact_identifiers
    assert_empty inventory.aal1_methods
    assert_empty inventory.aal2_methods
    assert_predicate inventory, :contactable?
    assert_not inventory.aal1_available?
    assert_not inventory.aal2_available?
  end

  test "actor concern exposes the same credential inventory service" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    client.client_emails.create!(
      address: "inventory-actor-concern@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    inventory = client.authentication_credential_inventory

    assert_instance_of Authentication::CredentialInventory::Result, inventory
    assert_equal Authentication::CredentialInventory.call(client).aal2_methods, inventory.aal2_methods
  end

  test "actor concern exposes aal and contactability removal checks independently" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    email = client.client_emails.create!(
      address: "inventory-owner-concern@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    client.client_telephones.create!(
      number: "+819011122244",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    client.client_one_time_passwords.create!(
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    assert_predicate client, :aal1_available?
    assert_predicate client, :aal2_available?
    assert_predicate client, :contactable?
    assert_not client.retains_aal1_after?(excluding: email)
    assert client.retains_aal2_after?(excluding: email)
    assert client.retains_contactability_after?(excluding: email)
  end

  private

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::BOTH)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
  end
end
