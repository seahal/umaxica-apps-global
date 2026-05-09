# typed: false
# frozen_string_literal: true

require "test_helper"

class ReferenceRecordTest < ActiveSupport::TestCase
  class DummyReference < ApplicationRecord
    # We create a simple class mimicking a reference table.
    # Usually they have just an id, but for tests we don't have a table.
    # Let's use an existing reference model for the test since ReferenceRecord requires a table.

    # We will test UserStatus as a real reference model.
  end

  test "record_timestamps is false" do
    assert_not UserStatus.record_timestamps
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal UserStatus::NOTHING, UserStatus.nothing_id
  end

  test "ensure_defaults! inserts defaults" do
    assert_nothing_raised do
      UserStatus.ensure_defaults!
    end
  end
end
