# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_identity_states
# Database name: app_zenith
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientIdentityStateTest < ActiveSupport::TestCase
  test "ensures default client identity states" do
    ClientIdentityState.ensure_defaults!

    assert_equal AppRpRecord.connection_db_config.name, ClientIdentityState.connection_db_config.name
    assert ClientIdentityState.exists?(ClientIdentityState::NOTHING)
    assert ClientIdentityState.exists?(ClientIdentityState::ACTIVE)
    assert ClientIdentityState.exists?(ClientIdentityState::SUSPENDED)
    assert ClientIdentityState.exists?(ClientIdentityState::DELETED)
  end
end
