# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_density_options
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientPreferenceDensityOptionTest < ActiveSupport::TestCase
  test "name returns standard for STANDARD id" do
    option = ClientPreferenceDensityOption.new(id: ClientPreferenceDensityOption::STANDARD)

    assert_equal "standard", option.name
  end

  test "name returns compact for COMPACT id" do
    option = ClientPreferenceDensityOption.new(id: ClientPreferenceDensityOption::COMPACT)

    assert_equal "compact", option.name
  end

  test "name returns nil for NOTHING id" do
    option = ClientPreferenceDensityOption.new(id: ClientPreferenceDensityOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = ClientPreferenceDensityOption.new(id: 999)

    assert_nil option.name
  end
end
