# typed: false
# frozen_string_literal: true

require "test_helper"

class AppRpRecordTest < ActiveSupport::TestCase
  test "should be abstract class" do
    assert_predicate AppRpRecord, :abstract_class?
  end

  test "should inherit from ApplicationRecord" do
    assert_operator AppRpRecord, :<, ApplicationRecord
  end

  test "should connect to app_zenith database" do
    assert_respond_to AppRpRecord, :connection_db_config
  end
end
