# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_apple_identity_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientAppleIdentityStatusTest < ActiveSupport::TestCase
  test "status constants are defined" do
    assert_equal 1, ClientAppleIdentityStatus::ACTIVE
    assert_equal 2, ClientAppleIdentityStatus::INACTIVE
    assert_equal 3, ClientAppleIdentityStatus::PENDING
    assert_equal 4, ClientAppleIdentityStatus::DELETED
    assert_equal 5, ClientAppleIdentityStatus::REVOKED
    assert_equal 6, ClientAppleIdentityStatus::NOTHING
  end

  test "status ids are integers" do
    assert_kind_of Integer, ClientAppleIdentityStatus::ACTIVE
    assert_kind_of Integer, ClientAppleIdentityStatus::INACTIVE
    assert_kind_of Integer, ClientAppleIdentityStatus::PENDING
    assert_kind_of Integer, ClientAppleIdentityStatus::DELETED
    assert_kind_of Integer, ClientAppleIdentityStatus::REVOKED
    assert_kind_of Integer, ClientAppleIdentityStatus::NOTHING
  end
end
