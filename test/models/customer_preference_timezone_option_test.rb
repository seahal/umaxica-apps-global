# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_preference_timezone_options
# Database name: guest
#
#  id :bigint           not null, primary key
#
require "test_helper"

class CustomerPreferenceTimezoneOptionTest < ActiveSupport::TestCase
  test "name returns Etc UTC for ETC_UTC id" do
    option = CustomerPreferenceTimezoneOption.find_or_create_by!(id: CustomerPreferenceTimezoneOption::ETC_UTC)

    assert_equal "Etc/UTC", option.name
  end

  test "name returns Asia Tokyo for ASIA_TOKYO id" do
    option = CustomerPreferenceTimezoneOption.find_or_create_by!(id: CustomerPreferenceTimezoneOption::ASIA_TOKYO)

    assert_equal "Asia/Tokyo", option.name
  end
end
