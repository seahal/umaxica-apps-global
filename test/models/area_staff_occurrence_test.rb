# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: area_staff_occurrences
# Database name: occurrence
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  area_occurrence_id  :bigint           not null
#  staff_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_area_staff_occ_on_ids                            (area_occurrence_id,staff_occurrence_id) UNIQUE
#  index_area_staff_occurrences_on_staff_occurrence_id  (staff_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (area_occurrence_id => area_occurrences.id)
#  fk_rails_...  (staff_occurrence_id => staff_occurrences.id)
#

require "test_helper"

class AreaOperatorOccurrenceTest < ActiveSupport::TestCase
  fixtures :area_occurrences

  test "associations" do
    area = area_occurrences(:one)
    staff = OperatorOccurrence.create!(body: "staff-001")
    record = AreaOperatorOccurrence.new(
      area_occurrence: area,
      staff_occurrence: staff,
    )

    assert record.save!
    assert_equal area, record.area_occurrence
    assert_equal staff, record.staff_occurrence
  end

  test "uniqueness validation" do
    area = area_occurrences(:one)
    staff = OperatorOccurrence.create!(body: "staff-002")
    AreaOperatorOccurrence.create!(area_occurrence: area, staff_occurrence: staff)
    duplicate = AreaOperatorOccurrence.new(area_occurrence: area, staff_occurrence: staff)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:area_occurrence_id]
  end
end
