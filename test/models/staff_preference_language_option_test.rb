# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_preference_language_options
# Database name: principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class StaffPreferenceLanguageOptionTest < ActiveSupport::TestCase
  def setup
    StaffPreferenceLanguageOption::DEFAULTS.each do |id|
      StaffPreferenceLanguageOption.find_or_create_by!(id: id)
    end
  end

  test "NOTHING constant is defined" do
    assert_equal 0, StaffPreferenceLanguageOption::NOTHING
  end

  test "JA constant is defined" do
    assert_equal 1, StaffPreferenceLanguageOption::JA
  end

  test "EN constant is defined" do
    assert_equal 2, StaffPreferenceLanguageOption::EN
  end

  test "DEFAULTS constant contains JA and EN" do
    assert_equal [1, 2], StaffPreferenceLanguageOption::DEFAULTS
  end

  test "name returns ja for JA id" do
    option = StaffPreferenceLanguageOption.find_or_create_by!(id: StaffPreferenceLanguageOption::JA)

    assert_equal "ja", option.name
  end

  test "name returns en for EN id" do
    option = StaffPreferenceLanguageOption.find_or_create_by!(id: StaffPreferenceLanguageOption::EN)

    assert_equal "en", option.name
  end

  test "name returns nil for NOTHING id" do
    option = StaffPreferenceLanguageOption.create!(id: StaffPreferenceLanguageOption::NOTHING)

    assert_nil option.name
  end

  test "name returns nil for unknown id" do
    option = StaffPreferenceLanguageOption.create!(id: 999)

    assert_nil option.name
  end

  test "has_many staff_preference_languages association" do
    assert_respond_to StaffPreferenceLanguageOption.new, :staff_preference_languages
  end

  test "ensure_defaults! creates missing option records" do
    StaffPreferenceLanguage.where(option_id: StaffPreferenceLanguageOption::EN).delete_all
    StaffPreferenceLanguageOption.where(id: StaffPreferenceLanguageOption::EN).delete_all

    assert_difference("StaffPreferenceLanguageOption.count", 1) do
      StaffPreferenceLanguageOption.ensure_defaults!
    end

    assert StaffPreferenceLanguageOption.exists?(id: StaffPreferenceLanguageOption::EN)
  end

  test "ensure_defaults! skips existing records" do
    assert_no_difference("StaffPreferenceLanguageOption.count") do
      StaffPreferenceLanguageOption.ensure_defaults!
    end
  end

  test "ensure_defaults! does nothing when all exist" do
    assert_no_difference("StaffPreferenceLanguageOption.count") do
      StaffPreferenceLanguageOption.ensure_defaults!
    end
  end

  test "primary_key is id" do
    assert_equal "id", StaffPreferenceLanguageOption.primary_key
  end

  test "staff_preference_languages association works with dependent restrict" do
    option = StaffPreferenceLanguageOption.find(StaffPreferenceLanguageOption::JA)
    staff = Staff.create!(status_id: StaffStatus::ACTIVE)

    pref = StaffPreference.create!(staff: staff)
    language = StaffPreferenceLanguage.create!(
      preference: pref,
      option_id: option.id,
    )

    assert_includes option.staff_preference_languages, language

    # Test restrict_with_error
    assert_not option.destroy
    assert_predicate option.errors[:base], :present?
  end
end
