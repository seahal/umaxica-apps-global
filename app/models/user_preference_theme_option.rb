# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_preference_theme_options
# Database name: principal
#
#  id :bigint           not null, primary key
#
class UserPreferenceThemeOption < PrincipalRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  LIGHT = 1
  DARK = 2
  SYSTEM = 3

  has_many :user_preference_themes,
           class_name: "UserPreferenceTheme",
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

  DEFAULTS = [NOTHING, LIGHT, DARK, SYSTEM].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
