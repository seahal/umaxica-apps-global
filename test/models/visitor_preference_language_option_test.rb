# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_language_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
# Indexes
#
#  index_visitor_preference_language_options_on_id  (id) UNIQUE
#
require "test_helper"

class VisitorPreferenceLanguageOptionTest < ActiveSupport::TestCase
  test "name returns ja for JA id" do
    option = VisitorPreferenceLanguageOption.find_or_create_by!(id: VisitorPreferenceLanguageOption::JA)

    assert_equal "ja", option.name
  end

  test "name returns en for EN id" do
    option = VisitorPreferenceLanguageOption.find_or_create_by!(id: VisitorPreferenceLanguageOption::EN)

    assert_equal "en", option.name
  end

  test "name returns nil for NOTHING id" do
    option = VisitorPreferenceLanguageOption.find_or_create_by!(id: VisitorPreferenceLanguageOption::NOTHING)

    assert_nil option.name
  end
end
