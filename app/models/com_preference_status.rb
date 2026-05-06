# typed: false
# == Schema Information
#
# Table name: com_preference_statuses
# Database name: setting
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

class ComPreferenceStatus < SettingRecord
  # Fixed IDs - do not modify these values
  DELETED = 1
  NOTHING = 2
  has_many :com_preferences,
           class_name: "ComPreference",
           foreign_key: "status_id",
           primary_key: "id",
           inverse_of: :com_preference_status,
           dependent: :restrict_with_error

  DEFAULTS = [DELETED, NOTHING].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
