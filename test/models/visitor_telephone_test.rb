# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_telephones
# Database name: com_principal
#
#  id                          :bigint           not null, primary key
#  discarded_at                :datetime         default(Infinity), not null
#  locked_at                   :datetime         default(-Infinity), not null
#  number                      :string           default(""), not null
#  number_digest               :string
#  otp_attempts_count          :integer          default(0), not null
#  otp_counter                 :text             default(""), not null
#  otp_expires_at              :datetime         default(-Infinity), not null
#  otp_private_key             :string           default(""), not null
#  purged_at                   :datetime         default(Infinity), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  public_id                   :string(21)       not null
#  visitor_id                  :bigint           not null
#  visitor_telephone_status_id :bigint           default(1), not null
#
# Indexes
#
#  index_visitor_telephones_on_active_number_digest         (number_digest) UNIQUE WHERE ((number_digest IS NOT NULL) AND (visitor_telephone_status_id <> 4))
#  index_visitor_telephones_on_discarded_at                 (discarded_at)
#  index_visitor_telephones_on_public_id                    (public_id) UNIQUE
#  index_visitor_telephones_on_purged_at                    (purged_at)
#  index_visitor_telephones_on_visitor_id                   (visitor_id)
#  index_visitor_telephones_on_visitor_telephone_status_id  (visitor_telephone_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_id => visitors.id)
#  fk_rails_...  (visitor_telephone_status_id => visitor_telephone_statuses.id)
#
require "test_helper"

class VisitorTelephoneTest < ActiveSupport::TestCase
  setup do
    ensure_visitor_reference_records!
    @visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
  end

  test "to_param returns public_id" do
    telephone = VisitorTelephone.create!(
      visitor: @visitor,
      number: "090-1234-#{rand(1000..9999)}",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )

    assert_equal telephone.public_id, telephone.to_param
  end

  test "rejects creating more than the maximum telephones per visitor" do
    status = VisitorTelephoneStatus.find(VisitorTelephoneStatus::UNVERIFIED)

    VisitorTelephone::MAX_TELEPHONES_PER_VISITOR.times do |index|
      VisitorTelephone.create!(
        visitor: @visitor,
        visitor_telephone_status: status,
        number: "090-2222-#{format("%04d", index)}",
        otp_counter: "0",
        otp_private_key: "secret",
      )
    end

    extra = VisitorTelephone.new(
      visitor: @visitor,
      visitor_telephone_status: status,
      number: "090-3333-0000",
      otp_counter: "0",
      otp_private_key: "secret",
    )

    assert_not extra.valid?
    assert_not_empty extra.errors[:base]
  end

  test "rejects duplicate number digest" do
    existing = VisitorTelephone.create!(
      visitor: @visitor,
      number: "090-4444-0000",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )
    duplicate = VisitorTelephone.new(
      visitor: @visitor,
      number: "+819044440000",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )

    assert_equal existing.number_digest, duplicate.tap(&:valid?).number_digest
    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:number]
  end

  test "deleted sign-up telephone does not reserve number forever" do
    VisitorTelephone.create!(
      visitor: @visitor,
      number: "+1 (555) 444-0001",
      visitor_telephone_status_id: VisitorTelephoneStatus::DELETED,
      otp_counter: "0",
      otp_private_key: "secret",
      discarded_at: 1.minute.ago,
      purged_at: 29.minutes.from_now,
    )
    retry_telephone = VisitorTelephone.new(
      visitor: @visitor,
      number: "+15554440001",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )

    assert_predicate retry_telephone, :valid?
    assert_difference "VisitorTelephone.count", 1 do
      retry_telephone.save!
    end
  end

  test "sets number digest from normalized input" do
    telephone = VisitorTelephone.create!(
      visitor: @visitor,
      number: "+1 (555) 765-4321",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
      otp_counter: "0",
      otp_private_key: "secret",
    )

    expected = IdentifierBlindIndex.bidx_for_telephone("+15557654321")

    assert_equal expected, telephone.number_digest
  end
end
