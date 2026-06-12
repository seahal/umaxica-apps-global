# typed: false
# frozen_string_literal: true

require "test_helper"

class ComTicketRecordTest < ActiveSupport::TestCase
  test "should be abstract class" do
    assert_predicate ComTicketRecord, :abstract_class?
  end

  test "should inherit from ApplicationRecord" do
    assert_operator ComTicketRecord, :<, ApplicationRecord
  end

  test "should connect to com_ticket database" do
    assert_respond_to ComTicketRecord, :connection_db_config
  end
end
