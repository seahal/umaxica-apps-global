# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customers
# Database name: guest
#
#  id                    :bigint           not null, primary key
#  deactivated_at        :datetime
#  deletable_at          :datetime         default(Infinity), not null
#  lock_version          :integer          default(0), not null
#  multi_factor_enabled  :boolean          default(FALSE), not null
#  scheduled_purge_at    :datetime
#  shreddable_at         :datetime         default(Infinity), not null
#  withdrawal_started_at :datetime
#  withdrawn_at          :datetime         default(Infinity)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  public_id             :string           default(""), not null
#  status_id             :bigint           default(2), not null
#  visibility_id         :bigint           default(1), not null
#
# Indexes
#
#  index_customers_on_deactivated_at         (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_customers_on_deletable_at           (deletable_at)
#  index_customers_on_public_id              (public_id) UNIQUE
#  index_customers_on_scheduled_purge_at     (scheduled_purge_at) WHERE (scheduled_purge_at IS NOT NULL)
#  index_customers_on_shreddable_at          (shreddable_at)
#  index_customers_on_status_id              (status_id)
#  index_customers_on_visibility_id          (visibility_id)
#  index_customers_on_withdrawal_started_at  (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_customers_on_withdrawn_at           (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => customer_statuses.id)
#  fk_rails_...  (visibility_id => customer_visibilities.id)
#

require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  def setup
    [1, 2, 3].each { |id| CustomerStatus.find_or_create_by!(id: id) }
    [0, 1, 2, 3].each { |id| CustomerVisibility.find_or_create_by!(id: id) }
    [1, 2, 3, 4].each { |id| CustomerTelephoneStatus.find_or_create_by!(id: id) }
    [1, 2, 3, 4].each { |id| CustomerEmailStatus.find_or_create_by!(id: id) }
    [1, 2, 3, 4, 5].each { |id| CustomerPasskeyStatus.find_or_create_by!(id: id) }
  end

  test "should be valid" do
    customer = Customer.create!

    assert_predicate customer, :valid?
  end

  test "public_id is auto-generated" do
    customer = Customer.create!

    assert_predicate customer.public_id, :present?
    assert_operator customer.public_id.length, :<=, 21
  end

  test "default status_id is nothing" do
    customer = Customer.create!

    assert_equal CustomerStatus::NOTHING, customer.status_id
  end

  test "default visibility_id is customer" do
    customer = Customer.create!

    assert_equal CustomerVisibility::CUSTOMER, customer.visibility_id
  end

  test "customer? should return true" do
    customer = Customer.create!

    assert_predicate customer, :customer?
  end

  test "user? should return false" do
    customer = Customer.create!

    assert_not customer.user?
  end

  test "staff? should return false" do
    customer = Customer.create!

    assert_not customer.staff?
  end

  test "login_allowed? is false for reserved status" do
    customer = Customer.create!(status_id: CustomerStatus::RESERVED)

    assert_not customer.login_allowed?
  end

  test "verified_email? returns true when customer has verified email" do
    customer = Customer.create!
    CustomerEmail.create!(
      customer: customer,
      address: "verified@example.com",
      confirm_policy: "1",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
    )

    assert_predicate customer, :verified_email?
  end

  test "verified_email? uses loaded customer_emails" do
    customer = Customer.create!
    CustomerEmail.create!(
      customer: customer,
      address: "loaded@example.com",
      confirm_policy: "1",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
    )
    customer.customer_emails.load

    assert_predicate customer, :verified_email?
  end

  test "verified_email? returns true when customer has verified_with_sign_up email" do
    customer = Customer.create!
    CustomerEmail.create!(
      customer: customer,
      address: "signup@example.com",
      confirm_policy: "1",
      customer_email_status_id: CustomerEmailStatus::VERIFIED_WITH_SIGN_UP,
    )

    assert_predicate customer, :verified_email?
  end

  test "verified_email? returns false when customer has no verified email" do
    customer = Customer.create!
    CustomerEmail.create!(
      customer: customer,
      address: "unverified@example.com",
      confirm_policy: "1",
      customer_email_status_id: CustomerEmailStatus::UNVERIFIED,
    )

    assert_not customer.verified_email?
  end

  test "verified_telephone? returns true when customer has verified telephone" do
    customer = Customer.create!
    CustomerTelephone.create!(
      customer: customer,
      number: "+15551234567",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )

    assert_predicate customer, :verified_telephone?
  end

  test "verified_telephone? uses loaded customer_telephones" do
    customer = Customer.create!
    CustomerTelephone.create!(
      customer: customer,
      number: "+15557654321",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    customer.customer_telephones.load

    assert_predicate customer, :verified_telephone?
  end

  test "verified_telephone? returns false when customer has no verified telephone" do
    customer = Customer.create!
    CustomerTelephone.create!(
      customer: customer,
      number: "+15551234567",
      customer_telephone_status_id: CustomerTelephoneStatus::UNVERIFIED,
    )

    assert_not customer.verified_telephone?
  end

  test "has_verified_pii? returns true when has verified email" do
    customer = Customer.create!
    CustomerEmail.create!(
      customer: customer,
      address: "verified@example.com",
      confirm_policy: "1",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
    )

    assert_predicate customer, :has_verified_pii?
  end

  test "has_verified_pii? returns true when has verified telephone" do
    customer = Customer.create!
    CustomerTelephone.create!(
      customer: customer,
      number: "+15551234567",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )

    assert_predicate customer, :has_verified_pii?
  end

  test "has_verified_pii? returns false when no verified identity" do
    customer = Customer.create!

    assert_not customer.has_verified_pii?
  end

  test "has_verified_recovery_identity? delegates to has_verified_pii?" do
    customer = Customer.create!

    assert_equal customer.has_verified_pii?, customer.has_verified_recovery_identity?
  end

  test "passkey_login_available? returns false when no passkeys" do
    customer = Customer.create!

    assert_not customer.passkey_login_available?
  end

  test "passkey_login_available? requires verified telephone" do
    customer = Customer.create!
    CustomerTelephone.create!(
      customer: customer,
      number: "+15550001111",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    CustomerPasskey.create!(
      customer: customer,
      webauthn_id: "customer-passkey-login",
      public_key: "test-public-key",
      description: "My Passkey",
    )

    assert_predicate customer, :passkey_login_available?
  end
end
