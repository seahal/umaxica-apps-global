# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_preference_themes
# Database name: principal
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_user_preference_themes_on_option_id      (option_id)
#  index_user_preference_themes_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_user_preference_themes_on_option_id      (option_id => user_preference_theme_options.id)
#  fk_user_preference_themes_on_preference_id  (preference_id => user_preferences.id)
#
class UserPreferenceTheme < PrincipalRecord
  belongs_to :preference, class_name: "UserPreference", inverse_of: :user_preference_theme
  belongs_to :option,
             class_name: "UserPreferenceThemeOption",
             inverse_of: :user_preference_themes,
             optional: true
  validates :preference_id, uniqueness: true
  validates :option_id, presence: true
  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= UserPreferenceThemeOption::SYSTEM
  end
end
