# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_social_google_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientSocialGoogleStatusTest < ActiveSupport::TestCase
  test "status constants are defined" do
    assert_equal 1, ClientSocialGoogleStatus::ACTIVE
    assert_equal 2, ClientSocialGoogleStatus::INACTIVE
    assert_equal 3, ClientSocialGoogleStatus::PENDING
    assert_equal 4, ClientSocialGoogleStatus::DELETED
    assert_equal 5, ClientSocialGoogleStatus::REVOKED
    assert_equal 6, ClientSocialGoogleStatus::NOTHING
  end

  test "status ids are integers" do
    assert_kind_of Integer, ClientSocialGoogleStatus::ACTIVE
    assert_kind_of Integer, ClientSocialGoogleStatus::INACTIVE
    assert_kind_of Integer, ClientSocialGoogleStatus::PENDING
    assert_kind_of Integer, ClientSocialGoogleStatus::DELETED
    assert_kind_of Integer, ClientSocialGoogleStatus::REVOKED
    assert_kind_of Integer, ClientSocialGoogleStatus::NOTHING
  end
end
