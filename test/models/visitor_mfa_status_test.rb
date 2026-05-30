# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_mfa_statuses
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class VisitorMfaStatusTest < ActiveSupport::TestCase
  test "fixed ids are stable" do
    assert_equal 0, VisitorMfaStatus::NOTHING
    assert_equal 1, VisitorMfaStatus::ACTIVE
    assert_equal 5, VisitorMfaStatus::UNCONFIGURED
  end
end
