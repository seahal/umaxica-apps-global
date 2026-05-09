# typed: false
# == Schema Information
#
# Table name: com_preference_theme_options
# Database name: setting
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

class ComPreferenceThemeOption < SettingRecord
  # Fixed IDs - do not modify these values
  LIGHT = 1
  DARK = 2
  SYSTEM = 3
  DEFAULTS = [LIGHT, DARK, SYSTEM].freeze

  has_many :com_preference_themes,
           class_name: "ComPreferenceTheme",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def name
    case id
    when LIGHT then "light"
    when DARK then "dark"
    when SYSTEM then "system"
    end
  end

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
