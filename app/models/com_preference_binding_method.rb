# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_binding_methods
# Database name: com_setting
#
#  id :bigint           not null, primary key
#
class ComPreferenceBindingMethod < ComSettingRecord
  include ReferenceRecord

  NOTHING = 0
  DBSC = 1
  LEGACY = 2
  DEFAULTS = [NOTHING, DBSC, LEGACY].freeze

  has_many :com_preferences,
           foreign_key: :binding_method_id,
           inverse_of: :com_preference_binding_method,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
