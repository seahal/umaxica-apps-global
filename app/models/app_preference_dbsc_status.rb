# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_dbsc_statuses
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
class AppPreferenceDbscStatus < AppSettingRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  ACTIVE = 1
  PENDING = 2
  FAILED = 3
  REVOKE = 4
  DEFAULTS = [NOTHING, ACTIVE, PENDING, FAILED, REVOKE].freeze

  has_many :app_preferences,
           foreign_key: :dbsc_status_id,
           inverse_of: :app_preference_dbsc_status,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
