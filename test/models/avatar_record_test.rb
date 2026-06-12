# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarRecordTest < ActiveSupport::TestCase
  test "should be abstract class" do
    assert_predicate AvatarRecord, :abstract_class?
  end

  test "should inherit from ApplicationRecord" do
    assert_operator AvatarRecord, :<, ApplicationRecord
  end

  test "should connect to avatar database" do
    assert_respond_to AvatarRecord, :connection_db_config
  end
end
