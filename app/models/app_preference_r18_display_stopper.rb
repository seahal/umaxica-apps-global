# typed: false
# frozen_string_literal: true

class AppPreferenceR18DisplayStopper < AppSettingRecord
  belongs_to :preference, class_name: "AppPreference", inverse_of: :app_preference_r18_display_stopper
  belongs_to :option,
             class_name: "AppPreferenceR18DisplayStopperOption",
             inverse_of: :app_preference_r18_display_stoppers

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def enabled? = option_id == AppPreferenceR18DisplayStopperOption::ENABLED

  private

  def set_option_id
    self.option_id ||= AppPreferenceR18DisplayStopperOption::DISABLED
  end
end
