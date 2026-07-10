# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_language_options
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientPreferenceLanguageOptionTest < ActiveSupport::TestCase
  test "name returns ja for JA id" do
    option = ClientPreferenceLanguageOption.find_or_create_by!(id: ClientPreferenceLanguageOption::JA)

    assert_equal "ja", option.name
  end

  test "name returns en for EN id" do
    option = ClientPreferenceLanguageOption.find_or_create_by!(id: ClientPreferenceLanguageOption::EN)

    assert_equal "en", option.name
  end

  test "name returns nil for unknown id" do
    option = ClientPreferenceLanguageOption.find_or_create_by!(id: 999)

    assert_nil option.name
  end
end
