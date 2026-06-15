# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_currency_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ComPreferenceCurrencyOptionTest < ActiveSupport::TestCase
  fixtures_none!

  test "name returns usd for USD id" do
    option = ComPreferenceCurrencyOption.new(id: ComPreferenceCurrencyOption::USD)

    assert_equal "usd", option.name
  end

  test "name returns jpy for JPY id" do
    option = ComPreferenceCurrencyOption.new(id: ComPreferenceCurrencyOption::JPY)

    assert_equal "jpy", option.name
  end

  test "name returns nil for NOTHING id" do
    option = ComPreferenceCurrencyOption.new(id: ComPreferenceCurrencyOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = ComPreferenceCurrencyOption.new(id: 999)

    assert_nil option.name
  end
end
