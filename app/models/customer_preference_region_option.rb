# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_preference_region_options
# Database name: setting
#
#  id :bigint           not null, primary key
#
class CustomerPreferenceRegionOption < SettingRecord
  include ReferenceRecord

  NOTHING = 0
  US = 1
  JP = 2

  has_many :customer_preference_regions,
           class_name: "CustomerPreferenceRegion",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def name
    case id
    when US then "US"
    when JP then "JP"
    end
  end

  DEFAULTS = [NOTHING, US, JP].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  self.primary_key = :id
end
