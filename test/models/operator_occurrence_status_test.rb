# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_occurrence_statuses
# Database name: occurrence
#
#  id   :bigint           not null, primary key
#  name :string           default(""), not null
#

require "test_helper"

class OperatorOccurrenceStatusTest < ActiveSupport::TestCase
  #   test "expires_at default" do
  #     record = OperatorOccurrenceStatus.new(id: "EXPIRES_AT_TEST")
  #
  #     assert_expires_at_default(record)
  #   end

  test "accepts integer ids" do
    record = OperatorOccurrenceStatus.new(id: 9)

    assert_predicate record, :valid?
  end

  test "constants are defined" do
    assert_equal 1, OperatorOccurrenceStatus::NOTHING
    assert_equal 2, OperatorOccurrenceStatus::ACTIVE
    assert_equal 3, OperatorOccurrenceStatus::INACTIVE
    assert_equal 4, OperatorOccurrenceStatus::DELETED
  end
end
