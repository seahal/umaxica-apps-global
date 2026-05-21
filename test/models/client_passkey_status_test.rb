# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_passkey_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientPasskeyStatusTest < ActiveSupport::TestCase
  fixtures :client_passkey_statuses

  test "status constants are defined" do
    assert_equal 1, ClientPasskeyStatus::ACTIVE
    assert_equal 2, ClientPasskeyStatus::DISABLED
    assert_equal 3, ClientPasskeyStatus::REVOKED
    assert_equal 4, ClientPasskeyStatus::DELETED
    assert_equal 5, ClientPasskeyStatus::NOTHING
  end

  test "status ids are integers" do
    assert_kind_of Integer, ClientPasskeyStatus::ACTIVE
    assert_kind_of Integer, ClientPasskeyStatus::DISABLED
    assert_kind_of Integer, ClientPasskeyStatus::REVOKED
    assert_kind_of Integer, ClientPasskeyStatus::DELETED
    assert_kind_of Integer, ClientPasskeyStatus::NOTHING
  end

  test "default ids include every fixed status" do
    assert_equal [
      ClientPasskeyStatus::ACTIVE,
      ClientPasskeyStatus::DISABLED,
      ClientPasskeyStatus::REVOKED,
      ClientPasskeyStatus::DELETED,
      ClientPasskeyStatus::NOTHING,
    ], ClientPasskeyStatus::DEFAULTS
  end

  test "ensure_defaults! keeps fixed status rows present" do
    ClientPasskeyStatus.ensure_defaults!

    assert_empty ClientPasskeyStatus::DEFAULTS - ClientPasskeyStatus.where(id: ClientPasskeyStatus::DEFAULTS).pluck(:id)
  end
end
