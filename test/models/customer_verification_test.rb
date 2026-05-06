# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_verifications
# Database name: symbol
#
#  id                :bigint           not null, primary key
#  expires_at        :datetime         not null
#  last_used_at      :datetime
#  revoked_at        :datetime
#  token_digest      :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  customer_token_id :bigint           not null
#
# Indexes
#
#  index_customer_verifications_on_customer_token_id  (customer_token_id)
#  index_customer_verifications_on_expires_at         (expires_at)
#  index_customer_verifications_on_token_digest       (token_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_token_id => customer_tokens.id)
#
require "test_helper"

class CustomerVerificationTest < ActiveSupport::TestCase
  setup do
    ensure_customer_reference_records!
    ensure_customer_token_reference_records!
    @customer = Customer.create!
    @token = CustomerToken.create!(customer: @customer, customer_token_kind_id: CustomerTokenKind::BROWSER_WEB)
  end

  test "active? reflects revoked and expiry state" do
    verification = CustomerVerification.create!(
      customer_token: @token,
      token_digest: CustomerVerification.digest_token("raw"),
      expires_at: 1.hour.from_now,
      last_used_at: Time.current,
    )

    assert_predicate verification, :active?

    verification.update!(expires_at: 1.minute.ago)

    assert_not verification.active?
  end

  test "issue_for_token! revokes previous active verification" do
    previous, = CustomerVerification.issue_for_token!(token: @token)

    replacement, raw_token = CustomerVerification.issue_for_token!(token: @token)

    assert_predicate raw_token, :present?
    assert_predicate replacement, :active?
    assert_predicate previous.reload.revoked_at, :present?
  end

  private

  def ensure_customer_reference_records!
    CustomerStatus.find_or_create_by!(id: CustomerStatus::ACTIVE)
    CustomerStatus.find_or_create_by!(id: CustomerStatus::NOTHING)
    CustomerStatus.find_or_create_by!(id: CustomerStatus::RESERVED)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::NOBODY)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::CUSTOMER)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::STAFF)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::BOTH)
  end

  def ensure_customer_token_reference_records!
    CustomerTokenStatus.find_or_create_by!(id: CustomerTokenStatus::NOTHING)
    CustomerTokenStatus.find_or_create_by!(id: CustomerTokenStatus::ACTIVE)
    CustomerTokenStatus.find_or_create_by!(id: CustomerTokenStatus::EXPIRED)
    CustomerTokenKind.find_or_create_by!(id: CustomerTokenKind::BROWSER_WEB)
    CustomerTokenBindingMethod.find_or_create_by!(id: CustomerTokenBindingMethod::NOTHING)
    CustomerTokenDbscStatus.find_or_create_by!(id: CustomerTokenDbscStatus::NOTHING)
  end
end
