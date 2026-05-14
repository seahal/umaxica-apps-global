# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_personnel_statuses
# Database name: personnel
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPersonnelStatusTest < ActiveSupport::TestCase
  test "ensures default personnel statuses" do
    OperatorPersonnelStatus.ensure_defaults!

    assert_equal PersonnelRecord.connection_db_config.name, OperatorPersonnelStatus.connection_db_config.name
    assert OperatorPersonnelStatus.exists?(OperatorPersonnelStatus::NOTHING)
    assert OperatorPersonnelStatus.exists?(OperatorPersonnelStatus::ACTIVE)
    assert OperatorPersonnelStatus.exists?(OperatorPersonnelStatus::SUSPENDED)
    assert OperatorPersonnelStatus.exists?(OperatorPersonnelStatus::DELETED)
  end
end
