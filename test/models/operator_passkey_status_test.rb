# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_passkey_statuses
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPasskeyStatusTest < ActiveSupport::TestCase
  fixtures :operator_passkey_statuses

  test "accepts integer ids" do
    status = OperatorPasskeyStatus.new(id: 9)

    assert_predicate status, :valid?
  end

  test "constants are defined" do
    assert_equal 1, OperatorPasskeyStatus::ACTIVE
    assert_equal 2, OperatorPasskeyStatus::REVOKED
  end
end
