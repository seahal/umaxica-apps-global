# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgSettingRecordTest < ActiveSupport::TestCase
  test "is an abstract application record" do
    assert_predicate OrgSettingRecord, :abstract_class?
    assert_operator OrgSettingRecord, :<, ApplicationRecord
  end

  test "connects to org setting database" do
    assert_equal "org_setting", OrgSettingRecord.connection_db_config.name
  end
end
