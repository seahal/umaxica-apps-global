# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_currency_options
# Database name: org_setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OrgPreferenceCurrencyOptionTest < ActiveSupport::TestCase
  test "name returns usd for USD id" do
    option = OrgPreferenceCurrencyOption.new(id: OrgPreferenceCurrencyOption::USD)

    assert_equal "usd", option.name
  end

  test "name returns jpy for JPY id" do
    option = OrgPreferenceCurrencyOption.new(id: OrgPreferenceCurrencyOption::JPY)

    assert_equal "jpy", option.name
  end

  test "name returns nil for NOTHING id" do
    option = OrgPreferenceCurrencyOption.new(id: OrgPreferenceCurrencyOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = OrgPreferenceCurrencyOption.new(id: 999)

    assert_nil option.name
  end

  test "ensure_defaults! creates default records" do
    OrgPreferenceCurrencyOption.ensure_defaults!

    OrgPreferenceCurrencyOption::DEFAULTS.each do |id|
      assert OrgPreferenceCurrencyOption.exists?(id), "missing default org preference currency option #{id}"
    end
  end
end
