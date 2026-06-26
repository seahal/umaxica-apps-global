# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::CommonHelperTest < ActionView::TestCase
  setup do
    extend Sign::CommonHelper
  end

  test "localized_session_timestamp falls back to strftime when short format is unavailable" do
    test_time = Time.zone.parse("2024-01-01 12:34:00 UTC")

    I18n.stub(:t, nil) do
      assert_equal "2024/01/01 12:34", localized_session_timestamp(test_time)
    end
  end

  test "sign up birthdate order follows date format preference" do
    assert_equal %w(year month day), sign_up_birthdate_part_order("iso")
    assert_equal %w(month day year), sign_up_birthdate_part_order("us")
    assert_equal %w(day month year), sign_up_birthdate_part_order("uk")
  end

  test "sign up birthdate fields use birthday autocomplete tokens" do
    original = Actor.preferences
    Actor.preferences = Actor::Preference.new(date_format: "us")

    html = sign_up_birthdate_fields("2000-02-03")
    fragment = Nokogiri::HTML.fragment(html)
    inputs = fragment.css("input")

    assert_includes html, 'data-birthdate-format="us"'
    assert_equal %w(birthdate_month birthdate_day birthdate_year), inputs.pluck("name")
    assert_equal %w(bday-month bday-day bday-year), inputs.pluck("autocomplete")
  ensure
    Actor.preferences = original
  end

  test "sign up birthdate labels are localized" do
    original = Actor.preferences
    Actor.preferences = Actor::Preference.new(date_format: "iso")

    I18n.with_locale(:en) do
      html = sign_up_birthdate_fields(nil)
      fragment = Nokogiri::HTML.fragment(html)

      assert_equal %w(YYYY MM DD), fragment.css("label").map { |label| label.text.split.first }
      assert_equal %w(YYYY MM DD), fragment.css("input").pluck("placeholder")
    end

    I18n.with_locale(:ja) do
      html = sign_up_birthdate_fields(nil)
      fragment = Nokogiri::HTML.fragment(html)

      assert_equal %w(年 月 日), fragment.css("label").map { |label| label.text.split.first }
      assert_equal %w(年 月 日), fragment.css("input").pluck("placeholder")
    end
  ensure
    Actor.preferences = original
  end

  test "get_timezone returns request timezone context" do
    assert_equal "asia/tokyo", get_timezone
  end

  test "get_language returns ja" do
    assert_equal "ja", get_language
  end

  test "get_region returns jp" do
    assert_equal "jp", get_region
  end

  test "get_theme returns sy" do
    assert_equal "sy", get_theme
  end

  test "preference language helpers choose localized labels and defaults" do
    option_struct = Struct.new(:id, :name)
    option_class =
      Class.new do
        define_singleton_method(:order) do |_column|
          [
            option_struct.new(1, "ja"),
            option_struct.new(2, "en"),
            option_struct.new(3, "fr"),
          ]
        end
      end
    option_class.const_set(:EN, 2)
    option_class.const_set(:JA, 1)

    I18n.with_locale(:en) do
      assert_equal [["日本語", 1], ["English", 2]], preference_language_options(option_class)
    end

    I18n.with_locale(:ja) do
      assert_equal [["日本語", 1], ["English", 2]], preference_language_options(option_class)
    end
  end
end
