# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationCredentialInventoryOwnerTest < ActiveSupport::TestCase
  class CredentialOwner
    include AuthenticationCredentialInventoryOwner
  end

  setup do
    @owner = CredentialOwner.new
    @excluding = Object.new
    @inventory =
      AuthenticationCredentialInventory::Result.new(
        actor: @owner,
        excluding: @excluding,
        aal1_methods: [:email_otp],
        aal2_methods: [:passkey],
        aal3_methods: [:hardware_key],
        contact_identifiers: [:email],
        phishing_resistant_methods: [:passkey],
      )
  end

  test "authentication inventory delegates to CredentialInventory with options" do
    calls = []
    replacement =
      lambda do |actor, excluding: nil, reload: false|
        calls << { actor: actor, excluding: excluding, reload: reload }
        @inventory
      end

    AuthenticationCredentialInventory.stub(:call, replacement) do
      assert_same @inventory, @owner.authentication_credential_inventory(excluding: @excluding, reload: true)
      assert_equal [{ actor: @owner, excluding: @excluding, reload: true }], calls
    end
  end

  test "authentication method inventory is an alias for credential inventory" do
    with_inventory do
      assert_same @inventory, @owner.authentication_method_inventory(excluding: @excluding)
    end
  end

  test "aal1 and login methods share inventory result" do
    with_inventory do
      assert_equal [:email_otp], @owner.aal1_methods(excluding: @excluding)
      assert_equal [:email_otp], @owner.login_methods(excluding: @excluding)
      assert_equal 1, @owner.aal1_method_count(excluding: @excluding)
      assert @owner.aal1_available?(excluding: @excluding)
      assert @owner.login_available?(excluding: @excluding)
      assert @owner.retains_aal1_after?(excluding: @excluding)
      assert @owner.retains_login_after?(excluding: @excluding)
    end
  end

  test "aal2 and step up methods share inventory result" do
    with_inventory do
      assert_equal [:passkey], @owner.aal2_methods(excluding: @excluding)
      assert_equal [:passkey], @owner.step_up_methods(excluding: @excluding)
      assert_equal 1, @owner.aal2_method_count(excluding: @excluding)
      assert @owner.aal2_available?(excluding: @excluding)
      assert @owner.step_up_available?(excluding: @excluding)
      assert @owner.retains_aal2_after?(excluding: @excluding)
      assert @owner.retains_step_up_after?(excluding: @excluding)
    end
  end

  test "contactability and aal3 methods expose inventory result" do
    with_inventory do
      assert_equal [:email], @owner.contact_identifiers(excluding: @excluding)
      assert_equal 1, @owner.contact_identifier_count(excluding: @excluding)
      assert @owner.contactable?(excluding: @excluding)
      assert @owner.retains_contactability_after?(excluding: @excluding)
      assert_equal [:hardware_key], @owner.aal3_methods(excluding: @excluding)
    end
  end

  private

  def with_inventory
    AuthenticationCredentialInventory.stub(:call, @inventory) do
      yield
    end
  end
end
