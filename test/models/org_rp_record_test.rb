# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgRpRecordTest < ActiveSupport::TestCase
  test "should be abstract class" do
    assert_predicate OrgRpRecord, :abstract_class?
  end

  test "should inherit from ApplicationRecord" do
    assert_operator OrgRpRecord, :<, ApplicationRecord
  end

  test "should connect to org_zenith database" do
    assert_respond_to OrgRpRecord, :connection_db_config
  end
end
