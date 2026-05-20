# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class OperatorIdentityStatusTest < ActiveSupport::TestCase
  fixtures :operator_identity_statuses

  test "status constants are defined" do
    assert_equal 1, OperatorIdentityStatus::ACTIVE
    assert_equal 2, OperatorIdentityStatus::NOTHING
    assert_equal 3, OperatorIdentityStatus::RESERVED
  end

  test "status ids are integers" do
    assert_kind_of Integer, OperatorIdentityStatus::ACTIVE
    assert_kind_of Integer, OperatorIdentityStatus::NOTHING
    assert_kind_of Integer, OperatorIdentityStatus::RESERVED
  end

  test "reserved fixture exists" do
    assert_equal OperatorIdentityStatus::RESERVED, operator_identity_statuses(:reserved).id
  end
end
