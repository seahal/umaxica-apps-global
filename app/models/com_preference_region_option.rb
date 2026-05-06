# typed: false
# == Schema Information
#
# Table name: com_preference_region_options
# Database name: setting
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

class ComPreferenceRegionOption < SettingRecord
  # Fixed IDs - do not modify these values
  US = 1
  JP = 2

  has_many :com_preference_regions,
           class_name: "ComPreferenceRegion",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def name
    case id
    when US then "US"
    when JP then "JP"
    end
  end

  DEFAULTS = [US, JP].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  self.primary_key = :id
end
