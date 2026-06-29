# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_occurrence_statuses
# Database name: occurrence
#
#  id   :bigint           not null, primary key
#  name :string           default(""), not null
#
require "test_helper"

class VisitorOccurrenceStatusTest < ActiveSupport::TestCase
  test "ensure defaults creates fixed ids" do
    VisitorOccurrenceStatus.ensure_defaults!

    assert_empty VisitorOccurrenceStatus::DEFAULTS - VisitorOccurrenceStatus.where(
      id: VisitorOccurrenceStatus::DEFAULTS,
    ).pluck(:id)
  end

  test "constants follow reference table defaults" do
    assert_equal 0, VisitorOccurrenceStatus::NOTHING
    assert_equal 1, VisitorOccurrenceStatus::ACTIVE
    assert_equal 2, VisitorOccurrenceStatus::INACTIVE
    assert_equal 3, VisitorOccurrenceStatus::DELETED
  end

  test "has many association with visitor occurrences" do
    assert_status_association(VisitorOccurrenceStatus, :visitor_occurrences)
  end
  private

  def assert_status_association(status_class, association_name)
    reflection = status_class.reflect_on_association(association_name)

    assert_not_nil reflection
  end
end
