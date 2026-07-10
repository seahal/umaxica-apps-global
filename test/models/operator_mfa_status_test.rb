# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_mfa_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorMfaStatusTest < ActiveSupport::TestCase
  test "fixed ids are stable" do
    assert_equal 0, OperatorMfaStatus::NOTHING
    assert_equal 1, OperatorMfaStatus::ACTIVE
    assert_equal 5, OperatorMfaStatus::UNCONFIGURED
  end
end
