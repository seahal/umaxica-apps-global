# typed: false
# == Schema Information
#
# Table name: app_preference_themes
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
#  index_app_preference_themes_on_option_id      (option_id)
#  index_app_preference_themes_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_app_preference_themes_on_option_id  (option_id => app_preference_theme_options.id)
#  fk_rails_...                           (preference_id => app_preferences.id)
#

# frozen_string_literal: true

class AppPreferenceTheme < PrincipalRecord
  belongs_to :preference, class_name: "AppPreference", inverse_of: :app_preference_theme
  belongs_to :option,
             class_name: "AppPreferenceThemeOption",
             inverse_of: :app_preference_themes,
             optional: true
  validates :preference_id, uniqueness: true
  validates :option_id, presence: true
  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= AppPreferenceThemeOption::SYSTEM
  end
end
