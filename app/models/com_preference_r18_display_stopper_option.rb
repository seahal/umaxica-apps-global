# typed: false
# frozen_string_literal: true

class ComPreferenceR18DisplayStopperOption < ComSettingRecord
  include ReferenceRecord

  DISABLED = 0
  ENABLED = 1
  DEFAULTS = [DISABLED, ENABLED].freeze

  has_many :com_preference_r18_display_stoppers,
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def name = id == ENABLED ? "enabled" : "disabled"

  def self.ensure_defaults! = insert_missing_fixed_ids!(DEFAULTS)
end
