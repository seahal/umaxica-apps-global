# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_multi_factor_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientMultiFactorStatusTest < ActiveSupport::TestCase
  test "fixed ids are stable" do
    assert_equal 0, ClientMultiFactorStatus::NOTHING
    assert_equal 1, ClientMultiFactorStatus::ACTIVE
    assert_equal 5, ClientMultiFactorStatus::UNCONFIGURED
  end
end
