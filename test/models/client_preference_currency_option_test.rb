# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_currency_options
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientPreferenceCurrencyOptionTest < ActiveSupport::TestCase
  test "name returns usd for USD id" do
    option = ClientPreferenceCurrencyOption.new(id: ClientPreferenceCurrencyOption::USD)

    assert_equal "usd", option.name
  end

  test "name returns jpy for JPY id" do
    option = ClientPreferenceCurrencyOption.new(id: ClientPreferenceCurrencyOption::JPY)

    assert_equal "jpy", option.name
  end

  test "name returns nil for NOTHING id" do
    option = ClientPreferenceCurrencyOption.new(id: ClientPreferenceCurrencyOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = ClientPreferenceCurrencyOption.new(id: 999)

    assert_nil option.name
  end
end
