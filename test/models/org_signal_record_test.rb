# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgSignalRecordTest < ActiveSupport::TestCase
  test "is abstract and inherits from ApplicationRecord" do
    assert_operator OrgSignalRecord, :<, ApplicationRecord
    assert_predicate OrgSignalRecord, :abstract_class?
  end
end
