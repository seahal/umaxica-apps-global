# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_region_options
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientPreferenceRegionOptionTest < ActiveSupport::TestCase
  test "name returns US for US id" do
    option = ClientPreferenceRegionOption.find_or_create_by!(id: ClientPreferenceRegionOption::US)

    assert_equal "US", option.name
  end

  test "name returns JP for JP id" do
    option = ClientPreferenceRegionOption.find_or_create_by!(id: ClientPreferenceRegionOption::JP)

    assert_equal "JP", option.name
  end

  test "name returns nil for NOTHING id" do
    option = ClientPreferenceRegionOption.find_or_create_by!(id: ClientPreferenceRegionOption::NOTHING)

    assert_nil option.name
  end
end
