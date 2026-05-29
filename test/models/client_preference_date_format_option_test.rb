# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_date_format_options
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientPreferenceDateFormatOptionTest < ActiveSupport::TestCase
  test "name returns iso for ISO id" do
    option = ClientPreferenceDateFormatOption.new(id: ClientPreferenceDateFormatOption::ISO)

    assert_equal "iso", option.name
  end

  test "name returns uk for UK id" do
    option = ClientPreferenceDateFormatOption.new(id: ClientPreferenceDateFormatOption::UK)

    assert_equal "uk", option.name
  end

  test "name returns us for US id" do
    option = ClientPreferenceDateFormatOption.new(id: ClientPreferenceDateFormatOption::US)

    assert_equal "us", option.name
  end

  test "name returns nil for NOTHING id" do
    option = ClientPreferenceDateFormatOption.new(id: ClientPreferenceDateFormatOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = ClientPreferenceDateFormatOption.new(id: 999)

    assert_nil option.name
  end
end
