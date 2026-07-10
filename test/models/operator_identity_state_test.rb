# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_identity_states
# Database name: org_zenith
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorIdentityStateTest < ActiveSupport::TestCase
  test "ensures default operator identity states" do
    OperatorIdentityState.ensure_defaults!

    assert_equal OrgRpRecord.connection_db_config.name, OperatorIdentityState.connection_db_config.name
    assert OperatorIdentityState.exists?(OperatorIdentityState::NOTHING)
    assert OperatorIdentityState.exists?(OperatorIdentityState::ACTIVE)
    assert OperatorIdentityState.exists?(OperatorIdentityState::SUSPENDED)
    assert OperatorIdentityState.exists?(OperatorIdentityState::DELETED)
  end
end
