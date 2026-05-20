# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_identity_states
# Database name: com_zenith
#
#  id :bigint           not null, primary key
#
require "test_helper"

class VisitorIdentityStateTest < ActiveSupport::TestCase
  test "ensures default visitor identity states" do
    VisitorIdentityState.ensure_defaults!

    assert_equal ComRpRecord.connection_db_config.name, VisitorIdentityState.connection_db_config.name
    assert VisitorIdentityState.exists?(VisitorIdentityState::NOTHING)
    assert VisitorIdentityState.exists?(VisitorIdentityState::ACTIVE)
    assert VisitorIdentityState.exists?(VisitorIdentityState::SUSPENDED)
    assert VisitorIdentityState.exists?(VisitorIdentityState::DELETED)
  end
end
