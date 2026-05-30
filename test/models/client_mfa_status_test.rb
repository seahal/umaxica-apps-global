# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_mfa_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientMfaStatusTest < ActiveSupport::TestCase
  test "fixed ids are stable" do
    assert_equal 0, ClientMfaStatus::NOTHING
    assert_equal 1, ClientMfaStatus::ACTIVE
    assert_equal 5, ClientMfaStatus::UNCONFIGURED
  end
end
