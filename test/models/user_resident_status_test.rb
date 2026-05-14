# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_resident_statuses
# Database name: resident
#
#  id :bigint           not null, primary key
#
require "test_helper"

class UserResidentStatusTest < ActiveSupport::TestCase
  test "ensures default resident statuses" do
    UserResidentStatus.ensure_defaults!

    assert_equal ResidentRecord.connection_db_config.name, UserResidentStatus.connection_db_config.name
    assert UserResidentStatus.exists?(UserResidentStatus::NOTHING)
    assert UserResidentStatus.exists?(UserResidentStatus::ACTIVE)
    assert UserResidentStatus.exists?(UserResidentStatus::SUSPENDED)
    assert UserResidentStatus.exists?(UserResidentStatus::DELETED)
  end
end
