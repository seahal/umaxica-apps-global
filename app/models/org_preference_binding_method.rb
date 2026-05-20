# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_binding_methods
# Database name: org_setting
#
#  id :bigint           not null, primary key
#
class OrgPreferenceBindingMethod < OrgSettingRecord
  include ReferenceRecord

  NOTHING = 0
  DBSC = 1
  LEGACY = 2
  DEFAULTS = [NOTHING, DBSC, LEGACY].freeze

  has_many :org_preferences,
           foreign_key: :binding_method_id,
           inverse_of: :org_preference_binding_method,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
