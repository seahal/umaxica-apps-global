# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_google_identity_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientGoogleIdentityStatusTest < ActiveSupport::TestCase
  test "status constants are defined" do
    assert_equal 1, ClientGoogleIdentityStatus::ACTIVE
    assert_equal 2, ClientGoogleIdentityStatus::INACTIVE
    assert_equal 3, ClientGoogleIdentityStatus::PENDING
    assert_equal 4, ClientGoogleIdentityStatus::DELETED
    assert_equal 5, ClientGoogleIdentityStatus::REVOKED
    assert_equal 6, ClientGoogleIdentityStatus::NOTHING
  end

  test "status ids are integers" do
    assert_kind_of Integer, ClientGoogleIdentityStatus::ACTIVE
    assert_kind_of Integer, ClientGoogleIdentityStatus::INACTIVE
    assert_kind_of Integer, ClientGoogleIdentityStatus::PENDING
    assert_kind_of Integer, ClientGoogleIdentityStatus::DELETED
    assert_kind_of Integer, ClientGoogleIdentityStatus::REVOKED
    assert_kind_of Integer, ClientGoogleIdentityStatus::NOTHING
  end
end
