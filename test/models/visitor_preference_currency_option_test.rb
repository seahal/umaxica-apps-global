# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_currency_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class VisitorPreferenceCurrencyOptionTest < ActiveSupport::TestCase
  test "name returns usd for USD id" do
    option = VisitorPreferenceCurrencyOption.new(id: VisitorPreferenceCurrencyOption::USD)

    assert_equal "usd", option.name
  end

  test "name returns jpy for JPY id" do
    option = VisitorPreferenceCurrencyOption.new(id: VisitorPreferenceCurrencyOption::JPY)

    assert_equal "jpy", option.name
  end

  test "name returns nil for NOTHING id" do
    option = VisitorPreferenceCurrencyOption.new(id: VisitorPreferenceCurrencyOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = VisitorPreferenceCurrencyOption.new(id: 999)

    assert_nil option.name
  end
end
