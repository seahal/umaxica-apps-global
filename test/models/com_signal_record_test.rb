# typed: false
# frozen_string_literal: true

require "test_helper"

class ComSignalRecordTest < ActiveSupport::TestCase
  test "is abstract and inherits from ApplicationRecord" do
    assert_operator ComSignalRecord, :<, ApplicationRecord
    assert_predicate ComSignalRecord, :abstract_class?
  end
end
