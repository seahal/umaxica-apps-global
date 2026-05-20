# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_preference_timezone_options
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
require "test_helper"

class ClientPreferenceTimezoneOptionTest < ActiveSupport::TestCase
  fixtures :client_preference_timezone_options

  test "returns Etc/UTC for ETC_UTC id" do
    option = client_preference_timezone_options(:etc_utc)

    assert_equal "Etc/UTC", option.name
  end

  test "returns Asia/Tokyo for ASIA_TOKYO id" do
    option = client_preference_timezone_options(:asia_tokyo)

    assert_equal "Asia/Tokyo", option.name
  end

  test "returns nil for unknown id" do
    option = ClientPreferenceTimezoneOption.new(id: 999)

    assert_nil option.name
  end

  test "ensure_defaults! creates missing default records" do
    Prosopite.pause do
      ClientPreferenceTimezoneOption.where(id: ClientPreferenceTimezoneOption::DEFAULTS).destroy_all
    end

    ClientPreferenceTimezoneOption.ensure_defaults!

    assert ClientPreferenceTimezoneOption.exists?(id: ClientPreferenceTimezoneOption::ETC_UTC)
    assert ClientPreferenceTimezoneOption.exists?(id: ClientPreferenceTimezoneOption::ASIA_TOKYO)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    ClientPreferenceTimezoneOption.ensure_defaults!
    initial_count = ClientPreferenceTimezoneOption.count

    ClientPreferenceTimezoneOption.ensure_defaults!

    assert_equal initial_count, ClientPreferenceTimezoneOption.count
  end

  test "DEFAULTS constant exists" do
    assert_equal [1, 2], ClientPreferenceTimezoneOption::DEFAULTS
  end

  test "has_many client_preference_timezones association" do
    option = client_preference_timezone_options(:etc_utc)

    assert_respond_to option, :client_preference_timezones
  end
end
