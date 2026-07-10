# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_motion_options
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientPreferenceMotionOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = ClientPreferenceMotionOption.new(id: ClientPreferenceMotionOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns reduced for REDUCED id" do
    option = ClientPreferenceMotionOption.new(id: ClientPreferenceMotionOption::REDUCED)

    assert_equal "reduced", option.name
  end

  test "name returns nil for NOTHING id" do
    option = ClientPreferenceMotionOption.new(id: ClientPreferenceMotionOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = ClientPreferenceMotionOption.new(id: 999)

    assert_nil option.name
  end
end
