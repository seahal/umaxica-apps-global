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

  test "should connect to org_principal database" do
    assert_respond_to OrgPrincipalRecord, :connection_db_config
  end
end
