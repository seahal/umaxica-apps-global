# typed: false
# == Schema Information
#
# Table name: com_preference_language_options
# Database name: setting
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

class ComPreferenceLanguageOption < SettingRecord
  # Fixed IDs - do not modify these values
  JA = 1
  EN = 2

  has_many :com_preference_languages,
           class_name: "ComPreferenceLanguage",
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
