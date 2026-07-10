# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: area_visitor_occurrences
# Database name: occurrence
#
#  id                    :bigint           not null, primary key
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  area_occurrence_id    :bigint           not null
#  visitor_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_area_visitor_occ_on_ids                              (area_occurrence_id,visitor_occurrence_id) UNIQUE
#  index_area_visitor_occurrences_on_visitor_occurrence_id  (visitor_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (area_occurrence_id => area_occurrences.id)
#  fk_rails_...  (visitor_occurrence_id => visitor_occurrences.id)
#
require "test_helper"

class AreaVisitorOccurrenceTest < ActiveSupport::TestCase
  fixtures :area_occurrences

  setup do
    VisitorOccurrenceStatus.ensure_defaults!
  end

  test "associations" do
    visitor = VisitorOccurrence.create!(body: "visitor-area-001")
    record = AreaVisitorOccurrence.new(
      area_occurrence: area_occurrences(:one),
      visitor_occurrence: visitor,
    )

    assert record.save!
    assert_equal area_occurrences(:one), record.area_occurrence
    assert_equal visitor, record.visitor_occurrence
  end

  test "uniqueness validation" do
    visitor = VisitorOccurrence.create!(body: "visitor-area-002")
    AreaVisitorOccurrence.create!(area_occurrence: area_occurrences(:one), visitor_occurrence: visitor)
    duplicate = AreaVisitorOccurrence.new(area_occurrence: area_occurrences(:one), visitor_occurrence: visitor)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:area_occurrence_id]
  end
end
