# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_multi_factor_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorMultiFactorStatusTest < ActiveSupport::TestCase
  test "fixed ids are stable" do
    assert_equal 0, OperatorMultiFactorStatus::NOTHING
    assert_equal 1, OperatorMultiFactorStatus::ACTIVE
    assert_equal 5, OperatorMultiFactorStatus::UNCONFIGURED
  end
end
