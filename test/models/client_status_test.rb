# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ClientStatusTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "status constants are defined" do
    expected_status_constants = {
      ACTIVE: 1,
      INACTIVE: 2,
      PENDING: 3,
      DELETED: 4,
      WITHDRAWN: 5,
      PENDING_DELETION: 6,
      PRE_WITHDRAWAL_CONDITION: 7,
      WITHDRAWAL_COMPLETED: 8,
      UNVERIFIED_WITH_SIGN_UP: 9,
      VERIFIED_WITH_SIGN_UP: 10,
      NOTHING: 11,
      GHOST: 12,
      RESERVED: 13,
    }

    actual_status_constants = {
      ACTIVE: ClientStatus::ACTIVE,
      INACTIVE: ClientStatus::INACTIVE,
      PENDING: ClientStatus::PENDING,
      DELETED: ClientStatus::DELETED,
      WITHDRAWN: ClientStatus::WITHDRAWN,
      PENDING_DELETION: ClientStatus::PENDING_DELETION,
      PRE_WITHDRAWAL_CONDITION: ClientStatus::PRE_WITHDRAWAL_CONDITION,
      WITHDRAWAL_COMPLETED: ClientStatus::WITHDRAWAL_COMPLETED,
      UNVERIFIED_WITH_SIGN_UP: ClientStatus::UNVERIFIED_WITH_SIGN_UP,
      VERIFIED_WITH_SIGN_UP: ClientStatus::VERIFIED_WITH_SIGN_UP,
      NOTHING: ClientStatus::NOTHING,
      GHOST: ClientStatus::GHOST,
      RESERVED: ClientStatus::RESERVED,
    }

    assert_equal expected_status_constants, actual_status_constants
  end

  test "reserved fixture exists" do
    assert_equal ClientStatus::RESERVED, client_statuses(:reserved).id
  end

  test "ensure_defaults restores missing fixed status rows" do
    ClientStatus.find(ClientStatus::VERIFIED_WITH_SIGN_UP).destroy!

    ClientStatus.ensure_defaults!

    assert ClientStatus.exists?(ClientStatus::VERIFIED_WITH_SIGN_UP)
    assert_empty ClientStatus::DEFAULTS - ClientStatus.where(id: ClientStatus::DEFAULTS).pluck(:id)
  end
end
