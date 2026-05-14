# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_visitor_statuses
# Database name: visitor
#
#  id :bigint           not null, primary key
#
require "test_helper"

class VisitorClientStatusTest < ActiveSupport::TestCase
  test "ensures default visitor statuses" do
    VisitorClientStatus.ensure_defaults!

    assert_equal VisitorRecord.connection_db_config.name, VisitorClientStatus.connection_db_config.name
    assert VisitorClientStatus.exists?(VisitorClientStatus::NOTHING)
    assert VisitorClientStatus.exists?(VisitorClientStatus::ACTIVE)
    assert VisitorClientStatus.exists?(VisitorClientStatus::SUSPENDED)
    assert VisitorClientStatus.exists?(VisitorClientStatus::DELETED)
  end
end
