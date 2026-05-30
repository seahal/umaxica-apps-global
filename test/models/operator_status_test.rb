# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OperatorStatusTest < ActiveSupport::TestCase
  fixtures :operator_statuses

  test "status constants are defined" do
    assert_equal 1, OperatorStatus::ACTIVE
    assert_equal 2, OperatorStatus::NOTHING
    assert_equal 3, OperatorStatus::RESERVED
  end

  test "status ids are integers" do
    assert_kind_of Integer, OperatorStatus::ACTIVE
    assert_kind_of Integer, OperatorStatus::NOTHING
    assert_kind_of Integer, OperatorStatus::RESERVED
  end

  test "reserved fixture exists" do
    assert_equal OperatorStatus::RESERVED, operator_statuses(:reserved).id
  end
end
