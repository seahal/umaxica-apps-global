# typed: false
# frozen_string_literal: true

require "test_helper"

class AppSignalRecordTest < ActiveSupport::TestCase
  test "is abstract and inherits from ApplicationRecord" do
    assert_operator AppSignalRecord, :<, ApplicationRecord
    assert_predicate AppSignalRecord, :abstract_class?
  end
end
