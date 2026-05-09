# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_preference_language_options
# Database name: setting
#
#  id :bigint           not null, primary key
#
require "test_helper"

class CustomerPreferenceLanguageOptionTest < ActiveSupport::TestCase
  test "name returns ja for JA id" do
    option = CustomerPreferenceLanguageOption.find_or_create_by!(id: CustomerPreferenceLanguageOption::JA)

    assert_equal "ja", option.name
  end

  test "name returns en for EN id" do
    option = CustomerPreferenceLanguageOption.find_or_create_by!(id: CustomerPreferenceLanguageOption::EN)

    assert_equal "en", option.name
  end

  test "name returns nil for NOTHING id" do
    option = CustomerPreferenceLanguageOption.find_or_create_by!(id: CustomerPreferenceLanguageOption::NOTHING)

    assert_nil option.name
  end
end
