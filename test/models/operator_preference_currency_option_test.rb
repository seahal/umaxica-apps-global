# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_currency_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorPreferenceCurrencyOptionTest < ActiveSupport::TestCase
  test "name returns usd for USD id" do
    option = OperatorPreferenceCurrencyOption.new(id: OperatorPreferenceCurrencyOption::USD)

    assert_equal "usd", option.name
  end

  test "name returns jpy for JPY id" do
    option = OperatorPreferenceCurrencyOption.new(id: OperatorPreferenceCurrencyOption::JPY)

    assert_equal "jpy", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OperatorPreferenceCurrencyOption.new(id: OperatorPreferenceCurrencyOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = OperatorPreferenceCurrencyOption.new(id: 999)

    assert_nil option.name
  end
end
