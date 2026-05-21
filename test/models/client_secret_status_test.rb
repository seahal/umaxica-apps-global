# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_secret_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientSecretStatusTest < ActiveSupport::TestCase
  test "status constants are defined" do
    assert_equal 1, ClientSecretStatus::ACTIVE
    assert_equal 2, ClientSecretStatus::EXPIRED
    assert_equal 3, ClientSecretStatus::REVOKED
    assert_equal 4, ClientSecretStatus::USED
    assert_equal 5, ClientSecretStatus::DELETED
    assert_equal 6, ClientSecretStatus::NOTHING
  end

  test "status ids are integers" do
    assert_kind_of Integer, ClientSecretStatus::ACTIVE
    assert_kind_of Integer, ClientSecretStatus::EXPIRED
    assert_kind_of Integer, ClientSecretStatus::REVOKED
    assert_kind_of Integer, ClientSecretStatus::USED
    assert_kind_of Integer, ClientSecretStatus::DELETED
    assert_kind_of Integer, ClientSecretStatus::NOTHING
  end
end
