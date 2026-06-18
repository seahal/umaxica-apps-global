# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_currency_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppPreferenceCurrencyOptionTest < ActiveSupport::TestCase
  test "name returns usd for USD id" do
    option = AppPreferenceCurrencyOption.new(id: AppPreferenceCurrencyOption::USD)

    assert_equal "usd", option.name
  end

  test "name returns jpy for JPY id" do
    option = AppPreferenceCurrencyOption.new(id: AppPreferenceCurrencyOption::JPY)

    assert_equal "jpy", option.name
  end

  test "name returns nil for NOTHING id" do
    option = AppPreferenceCurrencyOption.new(id: AppPreferenceCurrencyOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = AppPreferenceCurrencyOption.new(id: 999)

    assert_nil option.name
  end

  test "ensure_defaults! creates default records" do
    AppPreferenceCurrencyOption.ensure_defaults!

    AppPreferenceCurrencyOption::DEFAULTS.each do |id|
      assert AppPreferenceCurrencyOption.exists?(id), "missing default app preference currency option #{id}"
    end
  end
end
