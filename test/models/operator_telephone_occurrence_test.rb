# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_telephone_occurrences
# Database name: occurrence
#
#  id                      :bigint           not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  staff_occurrence_id     :bigint           not null
#  telephone_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_on_telephone_occurrence_id_de4dc4cae4  (telephone_occurrence_id)
#  idx_staff_telephone_occ_on_ids             (staff_occurrence_id,telephone_occurrence_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_occurrence_id => operator_occurrences.id)
#  fk_rails_...  (telephone_occurrence_id => telephone_occurrences.id)
#

require "test_helper"

class OperatorTelephoneOccurrenceTest < ActiveSupport::TestCase
  fixtures :telephone_occurrences

  test "associations" do
    staff = OperatorOccurrence.create!(body: "staff-001")
    record = OperatorTelephoneOccurrence.new(
      staff_occurrence: staff,
      telephone_occurrence: telephone_occurrences(:one),
    )

    assert record.save!
    assert_equal staff, record.staff_occurrence
    assert_equal telephone_occurrences(:one), record.telephone_occurrence
  end

  test "uniqueness validation" do
    staff = OperatorOccurrence.create!(body: "staff-002")
    OperatorTelephoneOccurrence.create!(
      staff_occurrence: staff,
      telephone_occurrence: telephone_occurrences(:one),
    )
    duplicate = OperatorTelephoneOccurrence.new(
      staff_occurrence: staff,
      telephone_occurrence: telephone_occurrences(:one),
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:staff_occurrence_id]
  end
end
