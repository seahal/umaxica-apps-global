# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class UserChronicleLevel < ChronicleRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  DEBUG = 1
  ERROR = 2
  INFO = 3
  NOTHING = 4
  WARN = 5

  has_many :user_chronicles,
           foreign_key: :level_id,
           dependent: :restrict_with_error,
           inverse_of: :user_chronicle_level

  DEFAULTS = [DEBUG, ERROR, INFO, NOTHING, WARN].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
