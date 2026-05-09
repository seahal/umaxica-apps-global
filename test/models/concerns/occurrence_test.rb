# typed: false
# frozen_string_literal: true

require "test_helper"

class OccurrenceTest < ActiveSupport::TestCase
  test "includes retainable defaults" do
    record = UserOccurrence.new

    assert_occurrence_lifecycle_defaults(record)
  end

  test "accessible? and purgeable? reflect retainable state" do
    record = UserOccurrence.new(lapses_at: 1.hour.from_now, purge_at: 1.hour.ago)

    assert_predicate record, :accessible?
    assert_predicate record, :purgeable?
  end
end
