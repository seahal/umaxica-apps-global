# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_google_identity_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorGoogleIdentityStatusTest < ActiveSupport::TestCase
  test "defines fixed status ids" do
    assert_equal 1, OperatorGoogleIdentityStatus::ACTIVE
    assert_equal 2, OperatorGoogleIdentityStatus::INACTIVE
    assert_equal 3, OperatorGoogleIdentityStatus::PENDING
    assert_equal 4, OperatorGoogleIdentityStatus::DELETED
    assert_equal 5, OperatorGoogleIdentityStatus::REVOKED
    assert_equal 6, OperatorGoogleIdentityStatus::NOTHING
  end
end
