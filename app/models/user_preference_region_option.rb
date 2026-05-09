# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_preference_region_options
# Database name: principal
#
#  id :bigint           not null, primary key
#
class UserPreferenceRegionOption < PrincipalRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  US = 1
  JP = 2

  has_many :user_preference_regions,
           class_name: "UserPreferenceRegion",
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
