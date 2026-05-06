# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_emails
# Database name: guest
#
#  id                        :bigint           not null, primary key
#  address                   :string           default(""), not null
#  address_bidx              :string
#  address_digest            :string
#  locked_at                 :datetime         default(Infinity), not null
#  notifiable                :boolean          default(TRUE), not null
#  otp_attempts_count        :integer          default(0), not null
#  otp_counter               :text             default(""), not null
#  otp_expires_at            :datetime         default(-Infinity), not null
#  otp_last_sent_at          :datetime         default(-Infinity), not null
#  otp_private_key           :string           default(""), not null
#  promotional               :boolean          default(TRUE), not null
#  subscribable              :boolean          default(TRUE), not null
#  undeletable               :boolean          default(FALSE), not null
#  verification_token_digest :binary
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  customer_email_status_id  :bigint           default(1), not null
#  customer_id               :bigint           not null
#  public_id                 :string(21)       not null
#
# Indexes
#
#  index_customer_emails_on_address_bidx              (address_bidx) UNIQUE WHERE (address_bidx IS NOT NULL)
#  index_customer_emails_on_address_digest            (address_digest) UNIQUE WHERE (address_digest IS NOT NULL)
#  index_customer_emails_on_customer_email_status_id  (customer_email_status_id)
#  index_customer_emails_on_customer_id               (customer_id)
#  index_customer_emails_on_lower_address             (lower((address)::text)) UNIQUE
#  index_customer_emails_on_otp_last_sent_at          (otp_last_sent_at)
#  index_customer_emails_on_public_id                 (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_email_status_id => customer_email_statuses.id)
#  fk_rails_...  (customer_id => customers.id)
#
require "test_helper"

class CustomerEmailTest < ActiveSupport::TestCase
  setup do
    @customer = create_verified_customer_with_email(
      email_address: "customer-model-#{SecureRandom.hex(4)}@example.com",
    )
    @valid_attributes = {
      address: "customer-email@example.com",
      confirm_policy: true,
      customer: @customer,
    }.freeze
  end

  test "blocks destroying an undeletable email" do
    customer_email = CustomerEmail.create!(@valid_attributes.merge(undeletable: true))

    assert_raises(ActiveRecord::RecordNotDestroyed) { customer_email.destroy! }
    assert_includes customer_email.errors[:base], "cannot delete a protected email address"
    assert_predicate customer_email.reload, :undeletable?
  end

  test "verification token can be generated and verified" do
    customer_email = CustomerEmail.create!(
      @valid_attributes.merge(address: "verify-#{SecureRandom.hex(4)}@example.com"),
    )

    raw_token = customer_email.generate_verification_token

    assert customer_email.verify_verification_token(raw_token)
    assert_not customer_email.verify_verification_token("wrong-token")
  end

  test "verification token fails when token or digest is blank" do
    customer_email = CustomerEmail.new(@valid_attributes)

    assert_not customer_email.verify_verification_token("")
    assert_not customer_email.verify_verification_token("raw-token")
  end

  test "rejects creating more than the maximum emails per customer" do
    CustomerEmail.where(customer: @customer).delete_all

    CustomerEmail::MAX_EMAILS_PER_CUSTOMER.times do
      CustomerEmail.create!(@valid_attributes.merge(address: "limit-#{SecureRandom.hex(4)}@example.com"))
    end

    extra = CustomerEmail.new(@valid_attributes.merge(address: "limit-extra-#{SecureRandom.hex(4)}@example.com"))

    assert_not extra.valid?
    assert_not_empty extra.errors[:base]
  end
end
