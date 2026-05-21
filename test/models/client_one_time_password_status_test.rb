# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_one_time_password_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientOneTimePasswordStatusTest < ActiveSupport::TestCase
  test "status constants are defined" do
    assert_equal 1, ClientOneTimePasswordStatus::ACTIVE
    assert_equal 2, ClientOneTimePasswordStatus::INACTIVE
    assert_equal 3, ClientOneTimePasswordStatus::REVOKED
    assert_equal 4, ClientOneTimePasswordStatus::DELETED
    assert_equal 5, ClientOneTimePasswordStatus::NOTHING
  end

  test "status ids are integers" do
    assert_kind_of Integer, ClientOneTimePasswordStatus::ACTIVE
    assert_kind_of Integer, ClientOneTimePasswordStatus::INACTIVE
    assert_kind_of Integer, ClientOneTimePasswordStatus::REVOKED
    assert_kind_of Integer, ClientOneTimePasswordStatus::DELETED
    assert_kind_of Integer, ClientOneTimePasswordStatus::NOTHING
  end
end
