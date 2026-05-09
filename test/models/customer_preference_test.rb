# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_preferences
# Database name: setting
#
#  id              :bigint           not null, primary key
#  consent_version :uuid
#  consented       :boolean          default(FALSE), not null
#  consented_at    :datetime
#  functional      :boolean          default(FALSE), not null
#  language        :string           default("ja"), not null
#  performant      :boolean          default(FALSE), not null
#  region          :string           default("jp"), not null
#  targetable      :boolean          default(FALSE), not null
#  theme           :string           default("sy"), not null
#  timezone        :string           default("Asia/Tokyo"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  customer_id     :bigint           not null
#
# Indexes
#
#  index_customer_preferences_on_customer_id  (customer_id) UNIQUE
#
require "test_helper"

class CustomerPreferenceTest < ActiveSupport::TestCase
  setup do
    [1, 2, 3].each { |id| CustomerStatus.find_or_create_by!(id: id) }
    [0, 1, 2, 3].each { |id| CustomerVisibility.find_or_create_by!(id: id) }
    CustomerPreferenceLanguageOption.ensure_defaults!
    CustomerPreferenceTimezoneOption.ensure_defaults!
    CustomerPreferenceRegionOption.ensure_defaults!
    CustomerPreferenceThemeOption.ensure_defaults!
  end

  test "belongs to customer and keeps defaults" do
    customer = Customer.create!
    preference = CustomerPreference.create!(customer: customer)

    assert_equal customer, preference.customer
    assert_not preference.consented
    assert_equal "ja", preference.language
    assert_equal "jp", preference.region
    assert_equal "Asia/Tokyo", preference.timezone
    assert_equal "sy", preference.theme
  end

  test "child preference records default to expected option ids" do
    preference = CustomerPreference.create!(customer: Customer.create!)

    language = CustomerPreferenceLanguage.create!(preference: preference)
    timezone = CustomerPreferenceTimezone.create!(preference: preference)
    region = CustomerPreferenceRegion.create!(preference: preference)
    theme = CustomerPreferenceTheme.create!(preference: preference)

    assert_equal CustomerPreferenceLanguageOption::JA, language.option_id
    assert_equal CustomerPreferenceTimezoneOption::ASIA_TOKYO, timezone.option_id
    assert_equal CustomerPreferenceRegionOption::JP, region.option_id
    assert_equal CustomerPreferenceThemeOption::SYSTEM, theme.option_id
  end
end
