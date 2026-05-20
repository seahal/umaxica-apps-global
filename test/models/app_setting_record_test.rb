# typed: false
# frozen_string_literal: true

require "test_helper"

class AppSettingRecordTest < ActiveSupport::TestCase
  test "is an abstract application record" do
    assert_predicate AppSettingRecord, :abstract_class?
    assert_operator AppSettingRecord, :<, ApplicationRecord
  end

  test "connects to app setting database" do
    assert_equal "app_setting", AppSettingRecord.connection_db_config.name
  end
end
