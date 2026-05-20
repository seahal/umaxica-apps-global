# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_preference_language_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OperatorPreferenceLanguageOption < OrgPrincipalRecord
  self.table_name = "staff_preference_language_options"
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  JA = 1
  EN = 2

  has_many :staff_preference_languages,
           class_name: "OperatorPreferenceLanguage",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error
  has_many :operator_preference_languages,
           class_name: "OperatorPreferenceLanguage",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def name
    case id
    when JA then "ja"
    when EN then "en"
    end
  end

  DEFAULTS = [JA, EN].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  self.primary_key = :id
end
