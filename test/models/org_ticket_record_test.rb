# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgTicketRecordTest < ActiveSupport::TestCase
  test "should be abstract class" do
    assert_predicate OrgTicketRecord, :abstract_class?
  end

  test "should inherit from ApplicationRecord" do
    assert_operator OrgTicketRecord, :<, ApplicationRecord
  end

  test "should connect to org_ticket database" do
    assert_respond_to OrgTicketRecord, :connection_db_config
  end
end
