# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_adult_content_gate_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPreferenceAdultContentGateOptionTest < ActiveSupport::TestCase
  test "name returns nothing for NOTHING id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::NOTHING)

    assert_equal "nothing", option.name
  end

  test "name returns approved for APPROVED id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::APPROVED)

    assert_equal "approved", option.name
  end

  test "name returns deny for DENY id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::DENY)

    assert_equal "deny", option.name
  end

  test "name returns nil for unknown id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: 999)

    assert_nil option.name
  end

  test "approved? returns true for APPROVED id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::APPROVED)

    assert_predicate option, :approved?
  end

  test "approved? returns false for DENY id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::DENY)

    assert_not option.approved?
  end

  test "approved? returns false for NOTHING id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::NOTHING)

    assert_not option.approved?
  end

  test "denied? returns true for DENY id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::DENY)

    assert_predicate option, :denied?
  end

  test "denied? returns false for APPROVED id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::APPROVED)

    assert_not option.denied?
  end

  test "denied? returns false for NOTHING id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::NOTHING)

    assert_not option.denied?
  end

  test "enabled? returns true for DENY id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::DENY)

    assert_predicate option, :enabled?
  end

  test "enabled? returns false for APPROVED id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::APPROVED)

    assert_not option.enabled?
  end

  test "enabled? returns false for NOTHING id" do
    option = OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::NOTHING)

    assert_not option.enabled?
  end
end
