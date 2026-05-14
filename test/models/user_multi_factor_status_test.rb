# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_multi_factor_statuses
# Database name: principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class UserMultiFactorStatusTest < ActiveSupport::TestCase
  test "fixed ids are stable" do
    assert_equal 0, UserMultiFactorStatus::NOTHING
    assert_equal 1, UserMultiFactorStatus::ACTIVE
    assert_equal 5, UserMultiFactorStatus::UNCONFIGURED
  end
end
