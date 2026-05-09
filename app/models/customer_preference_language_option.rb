# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_preference_language_options
# Database name: setting
#
#  id :bigint           not null, primary key
#
class CustomerPreferenceLanguageOption < SettingRecord
  include ReferenceRecord

  NOTHING = 0
  JA = 1
  EN = 2

  has_many :customer_preference_languages,
           class_name: "CustomerPreferenceLanguage",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def name
    case id
    when JA then "ja"
    when EN then "en"
    end
  end

  DEFAULTS = [NOTHING, JA, EN].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end

  self.primary_key = :id
end
