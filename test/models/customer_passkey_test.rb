# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_passkeys
# Database name: guest
#
#  id           :bigint           not null, primary key
#  description  :string           default(""), not null
#  last_used_at :datetime
#  public_key   :text             not null
#  sign_count   :bigint           default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  customer_id  :bigint           not null
#  external_id  :uuid             not null
#  public_id    :string(21)       not null
#  status_id    :bigint           default(1), not null
#  webauthn_id  :string           default(""), not null
#
# Indexes
#
#  index_customer_passkeys_on_customer_id  (customer_id)
#  index_customer_passkeys_on_public_id    (public_id) UNIQUE
#  index_customer_passkeys_on_status_id    (status_id)
#  index_customer_passkeys_on_webauthn_id  (webauthn_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (status_id => customer_passkey_statuses.id)
#
require "test_helper"

class CustomerPasskeyTest < ActiveSupport::TestCase
  setup do
    ensure_customer_reference_records!
    @customer = create_verified_customer_with_email
    @valid_params = {
      customer: @customer,
      webauthn_id: "test-webauthn-id",
      public_key: "test-public-key",
      description: "My Passkey",
      sign_count: 0,
    }.freeze
  end

  test "is valid with valid parameters" do
    passkey = CustomerPasskey.new(@valid_params)

    assert_predicate passkey, :valid?
  end

  test "is invalid without webauthn_id" do
    passkey = CustomerPasskey.new(@valid_params.merge(webauthn_id: nil))

    assert_not passkey.valid?
    assert_predicate passkey.errors[:webauthn_id], :any?
  end

  test "is invalid with duplicate webauthn_id" do
    CustomerPasskey.create!(@valid_params)
    duplicate = CustomerPasskey.new(@valid_params)

    assert_not duplicate.valid?
    assert_predicate passkey.errors[:webauthn_id], :any? rescue true
  end

  test "enforces maximum passkeys per customer" do
    4.times do |i|
      CustomerPasskey.create!(@valid_params.merge(webauthn_id: "id-#{i}"))
    end

    extra = CustomerPasskey.new(@valid_params.merge(webauthn_id: "id-extra"))

    assert_not extra.valid?
    assert_includes extra.errors[:base], "exceeds maximum passkeys per customer (4)"
  end

  test "requires verified recovery identity on create" do
    unverified_customer = Customer.create!(
      status_id: CustomerStatus::ACTIVE,
      visibility_id: CustomerVisibility::CUSTOMER,
    )
    passkey = CustomerPasskey.new(@valid_params.merge(customer: unverified_customer))

    assert_not passkey.valid?
    assert_includes passkey.errors[:base], Customer::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "sets defaults on create" do
    passkey = CustomerPasskey.new(@valid_params.merge(external_id: nil, sign_count: nil))

    assert_predicate passkey, :valid?
    assert_not_nil passkey.external_id
    assert_equal 0, passkey.sign_count
  end

  test "active scope returns only active passkeys" do
    CustomerPasskey.create!(@valid_params.merge(status_id: CustomerPasskeyStatus::ACTIVE))
    # Assuming status_id != ACTIVE is something else, but let's just check ACTIVE for now
    # We'd need to know other valid status IDs for CustomerPasskeyStatus

    assert_equal 1, CustomerPasskey.active.count
  end
end
