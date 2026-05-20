# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_zip_occurrences
# Database name: occurrence
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  staff_occurrence_id :bigint           not null
#  zip_occurrence_id   :bigint           not null
#
# Indexes
#
#  idx_staff_zip_occ_on_ids                          (staff_occurrence_id,zip_occurrence_id) UNIQUE
#  index_staff_zip_occurrences_on_zip_occurrence_id  (zip_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_occurrence_id => staff_occurrences.id)
#  fk_rails_...  (zip_occurrence_id => zip_occurrences.id)
#

require "test_helper"

class OperatorZipOccurrenceTest < ActiveSupport::TestCase
  fixtures :zip_occurrences

  test "associations" do
    staff = OperatorOccurrence.create!(body: "staff-001")
    record = OperatorZipOccurrence.new(
      staff_occurrence: staff,
      zip_occurrence: zip_occurrences(:one),
    )

    assert record.save!
    assert_equal staff, record.staff_occurrence
    assert_equal zip_occurrences(:one), record.zip_occurrence
  end

  test "uniqueness validation" do
    staff = OperatorOccurrence.create!(body: "staff-002")
    OperatorZipOccurrence.create!(
      staff_occurrence: staff,
      zip_occurrence: zip_occurrences(:one),
    )
    duplicate = OperatorZipOccurrence.new(
      staff_occurrence: staff,
      zip_occurrence: zip_occurrences(:one),
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:staff_occurrence_id]
  end
end
