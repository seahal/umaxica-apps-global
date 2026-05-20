# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_social_apple_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientSocialAppleStatusTest < ActiveSupport::TestCase
  test "status constants are defined" do
    assert_equal 1, ClientSocialAppleStatus::ACTIVE
    assert_equal 2, ClientSocialAppleStatus::INACTIVE
    assert_equal 3, ClientSocialAppleStatus::PENDING
    assert_equal 4, ClientSocialAppleStatus::DELETED
    assert_equal 5, ClientSocialAppleStatus::REVOKED
    assert_equal 6, ClientSocialAppleStatus::NOTHING
  end

  test "status ids are integers" do
    assert_kind_of Integer, ClientSocialAppleStatus::ACTIVE
    assert_kind_of Integer, ClientSocialAppleStatus::INACTIVE
    assert_kind_of Integer, ClientSocialAppleStatus::PENDING
    assert_kind_of Integer, ClientSocialAppleStatus::DELETED
    assert_kind_of Integer, ClientSocialAppleStatus::REVOKED
    assert_kind_of Integer, ClientSocialAppleStatus::NOTHING
  end
end
