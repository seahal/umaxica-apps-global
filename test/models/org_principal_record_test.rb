# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgPrincipalRecordTest < ActiveSupport::TestCase
  test "should be abstract class" do
    assert_predicate OrgPrincipalRecord, :abstract_class?
  end

  test "should inherit from ApplicationRecord" do
    assert_operator OrgPrincipalRecord, :<, ApplicationRecord
  end

  test "uses the consolidated org zenith database" do
    assert_equal "org_zenith", OrgPrincipalRecord.connection_db_config.name
    assert_equal OrgRpRecord.connection_db_config.name, OrgPrincipalRecord.connection_db_config.name
  end
end
