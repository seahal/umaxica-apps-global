# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_contact_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class AppContactChronicleLevel < ChronicleRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  LEGACY_NOTHING = 1
  DEBUG = 2
  INFO = 3
  WARN = 4
  ERROR = 5
  DEFAULTS = [NOTHING, LEGACY_NOTHING, DEBUG, INFO, WARN, ERROR].freeze

  has_many :app_contact_chronicles, dependent: :restrict_with_error, inverse_of: :app_contact_chronicle_level

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
