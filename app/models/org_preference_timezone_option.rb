# typed: false
# == Schema Information
#
# Table name: org_preference_timezone_options
# Database name: operator
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

class OrgPreferenceTimezoneOption < OperatorRecord
  self.primary_key = :id
  # Fixed IDs - do not modify these values
  ETC_UTC = 1
  ASIA_TOKYO = 2

  has_many :org_preference_timezones,
           class_name: "OrgPreferenceTimezone",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def name
    case id
    when ETC_UTC then "Etc/UTC"
    when ASIA_TOKYO then "Asia/Tokyo"
    end
  end

  DEFAULTS = [ETC_UTC, ASIA_TOKYO].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  private
end
