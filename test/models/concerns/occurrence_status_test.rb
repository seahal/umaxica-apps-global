# typed: false
# frozen_string_literal: true

require "test_helper"

class OccurrenceStatusTest < ActiveSupport::TestCase
  class DummyOccurrenceStatus < OccurrenceRecord
    self.table_name = "user_occurrences"
    include OccurrenceStatus
  end

  test "retains no lifecycle helper methods" do
    record = DummyOccurrenceStatus.new

    assert_not record.respond_to?(:set_default_lifecycle_timestamps)
    assert_not record.respond_to?(:ensure_lifecycle_timestamps)
  end

  test "does not add lifecycle attributes on status rows" do
    record = UserOccurrenceStatus.new

    assert_not record.has_attribute?(:lapses_at)
    assert_not record.has_attribute?(:purge_at)
  end
end
