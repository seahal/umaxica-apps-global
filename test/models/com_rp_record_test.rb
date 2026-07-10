# typed: false
# frozen_string_literal: true

require "test_helper"

class ComRpRecordTest < ActiveSupport::TestCase
  test "should be abstract class" do
    assert_predicate ComRpRecord, :abstract_class?
  end

  test "should inherit from ApplicationRecord" do
    assert_operator ComRpRecord, :<, ApplicationRecord
  end

  test "should connect to com_zenith database" do
    assert_respond_to ComRpRecord, :connection_db_config
  end
end
