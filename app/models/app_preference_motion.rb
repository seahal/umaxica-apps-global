# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_motions
# Database name: app_setting
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_app_preference_motions_on_option_id      (option_id)
#  index_app_preference_motions_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (option_id => app_preference_motion_options.id)
#  fk_rails_...  (preference_id => app_preferences.id)
#
class AppPreferenceMotion < AppSettingRecord
  belongs_to :preference, class_name: "AppPreference", inverse_of: :app_preference_motion
  belongs_to :option,
             class_name: "AppPreferenceMotionOption",
             inverse_of: :app_preference_motions

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= AppPreferenceMotionOption::STANDARD
  end
end
