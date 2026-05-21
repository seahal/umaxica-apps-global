# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_social_google_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorSocialGoogleStatusTest < ActiveSupport::TestCase
  test "defines fixed status ids" do
    assert_equal 1, OperatorSocialGoogleStatus::ACTIVE
    assert_equal 2, OperatorSocialGoogleStatus::INACTIVE
    assert_equal 3, OperatorSocialGoogleStatus::PENDING
    assert_equal 4, OperatorSocialGoogleStatus::DELETED
    assert_equal 5, OperatorSocialGoogleStatus::REVOKED
    assert_equal 6, OperatorSocialGoogleStatus::NOTHING
  end
end
