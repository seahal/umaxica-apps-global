# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_dbsc_statuses
# Database name: setting
#
#  id :bigint           not null, primary key
#
class ComPreferenceDbscStatus < SettingRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  ACTIVE = 1
  PENDING = 2
  FAILED = 3
  REVOKE = 4
  DEFAULTS = [NOTHING, ACTIVE, PENDING, FAILED, REVOKE].freeze

  has_many :com_preferences,
           foreign_key: :dbsc_status_id,
           inverse_of: :com_preference_dbsc_status,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
