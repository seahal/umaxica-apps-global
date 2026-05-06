# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class AppPreferenceChronicleLevel < ChronicleRecord
  self.record_timestamps = false
  # Fixed IDs - do not modify these values
  NOTHING = 0
  INFO = 1

  has_many :app_preference_chronicles, dependent: :restrict_with_error, inverse_of: :app_preference_chronicle_level

  DEFAULTS = [NOTHING, INFO].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
