# typed: false
# frozen_string_literal: true

require "test_helper"

class OccurrenceTest < ActiveSupport::TestCase
  test "includes retainable defaults" do
    record = ClientOccurrence.new

    assert_occurrence_lifecycle_defaults(record)
  end

  test "accessible? and purgeable? reflect retainable state" do
    record = ClientOccurrence.new(discarded_at: 1.hour.from_now, purged_at: 1.hour.ago)

    assert_predicate record, :accessible?
    assert_predicate record, :purgeable?
  end
end
