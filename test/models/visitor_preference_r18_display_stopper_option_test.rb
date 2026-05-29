# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_r18_display_stopper_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class VisitorPreferenceR18DisplayStopperOptionTest < ActiveSupport::TestCase
  test "name returns nothing for NOTHING id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::NOTHING)

    assert_equal "nothing", option.name
  end

  test "name returns approved for APPROVED id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::APPROVED)

    assert_equal "approved", option.name
  end

  test "name returns deny for DENY id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::DENY)

    assert_equal "deny", option.name
  end

  test "name returns nil for unknown id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: 999)

    assert_nil option.name
  end

  test "approved? returns true for APPROVED id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::APPROVED)

    assert_predicate option, :approved?
  end

  test "approved? returns false for DENY id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::DENY)

    assert_not option.approved?
  end

  test "approved? returns false for NOTHING id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::NOTHING)

    assert_not option.approved?
  end

  test "denied? returns true for DENY id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::DENY)

    assert_predicate option, :denied?
  end

  test "denied? returns false for APPROVED id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::APPROVED)

    assert_not option.denied?
  end

  test "denied? returns false for NOTHING id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::NOTHING)

    assert_not option.denied?
  end

  test "enabled? returns true for DENY id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::DENY)

    assert_predicate option, :enabled?
  end

  test "enabled? returns false for APPROVED id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::APPROVED)

    assert_not option.enabled?
  end

  test "enabled? returns false for NOTHING id" do
    option = VisitorPreferenceR18DisplayStopperOption.new(id: VisitorPreferenceR18DisplayStopperOption::NOTHING)

    assert_not option.enabled?
  end
end
