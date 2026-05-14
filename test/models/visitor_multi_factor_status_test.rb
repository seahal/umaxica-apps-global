# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_multi_factor_statuses
# Database name: guest
#
#  id :bigint           not null, primary key
#
require "test_helper"

class VisitorMultiFactorStatusTest < ActiveSupport::TestCase
  test "fixed ids are stable" do
    assert_equal 0, VisitorMultiFactorStatus::NOTHING
    assert_equal 1, VisitorMultiFactorStatus::ACTIVE
    assert_equal 5, VisitorMultiFactorStatus::UNCONFIGURED
  end
end
