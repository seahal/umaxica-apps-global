# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_telephones
# Database name: guest
#
#  id                           :bigint           not null, primary key
#  locked_at                    :datetime         default(-Infinity), not null
#  number                       :string           default(""), not null
#  number_bidx                  :string
#  number_digest                :string
#  otp_attempts_count           :integer          default(0), not null
#  otp_counter                  :text             default(""), not null
#  otp_expires_at               :datetime         default(-Infinity), not null
#  otp_private_key              :string           default(""), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  customer_id                  :bigint           not null
#  customer_telephone_status_id :bigint           default(1), not null
#  public_id                    :string(21)       not null
#
# Indexes
#
#  index_customer_telephones_on_customer_id                   (customer_id)
#  index_customer_telephones_on_customer_telephone_status_id  (customer_telephone_status_id)
#  index_customer_telephones_on_lower_number                  (lower((number)::text)) UNIQUE
#  index_customer_telephones_on_number_bidx                   (number_bidx) UNIQUE WHERE (number_bidx IS NOT NULL)
#  index_customer_telephones_on_number_digest                 (number_digest) UNIQUE WHERE (number_digest IS NOT NULL)
#  index_customer_telephones_on_public_id                     (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (customer_telephone_status_id => customer_telephone_statuses.id)
#
require "test_helper"

class CustomerTelephoneTest < ActiveSupport::TestCase
  setup do
    ensure_customer_reference_records!
    @customer = Customer.create!(status_id: CustomerStatus::ACTIVE, visibility_id: CustomerVisibility::CUSTOMER)
  end

  test "to_param returns public_id" do
    telephone = CustomerTelephone.create!(
      customer: @customer,
      number: "090-1234-#{rand(1000..9999)}",
      customer_telephone_status_id: CustomerTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )

    assert_equal telephone.public_id, telephone.to_param
  end

  test "rejects creating more than the maximum telephones per customer" do
    CustomerTelephone::MAX_TELEPHONES_PER_CUSTOMER.times do |index|
      CustomerTelephone.create!(
        customer: @customer,
        number: "090-2222-#{format("%04d", index)}",
        customer_telephone_status_id: CustomerTelephoneStatus::UNVERIFIED,
        otp_counter: "0",
        otp_private_key: "secret",
      )
    end

    extra = CustomerTelephone.new(
      customer: @customer,
      number: "090-3333-0000",
      customer_telephone_status_id: CustomerTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )

    assert_not extra.valid?
    assert_not_empty extra.errors[:base]
  end

  test "rejects duplicate number digest" do
    existing = CustomerTelephone.create!(
      customer: @customer,
      number: "090-4444-0000",
      customer_telephone_status_id: CustomerTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )
    duplicate = CustomerTelephone.new(
      customer: @customer,
      number: "+819044440000",
      customer_telephone_status_id: CustomerTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )

    assert_equal existing.number_digest, duplicate.tap(&:valid?).number_digest
    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:number]
  end

  test "sets number digest from normalized input" do
    telephone = CustomerTelephone.create!(
      customer: @customer,
      number: "+1 (555) 765-4321",
      customer_telephone_status_id: CustomerTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )

    expected = IdentifierBlindIndex.bidx_for_telephone("+15557654321")

    assert_equal expected, telephone.number_bidx
    assert_equal expected, telephone.number_digest
  end
end
