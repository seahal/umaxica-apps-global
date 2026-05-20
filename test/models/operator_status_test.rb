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
  test "accepts integer ids" do
    record = OperatorStatus.new(id: 9)

    assert_predicate record, :valid?
  end

  test "constants are defined" do
    assert_equal 1, OperatorStatus::ACTIVE
    assert_equal 2, OperatorStatus::NOTHING
  end
end
