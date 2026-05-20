# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_binding_methods
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
class AppPreferenceBindingMethod < AppSettingRecord
  include ReferenceRecord

  NOTHING = 0
  DBSC = 1
  LEGACY = 2
  DEFAULTS = [NOTHING, DBSC, LEGACY].freeze

  has_many :app_preferences,
           foreign_key: :binding_method_id,
           inverse_of: :app_preference_binding_method,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
