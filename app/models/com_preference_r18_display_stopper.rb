# typed: false
# frozen_string_literal: true

class ComPreferenceR18DisplayStopper < ComSettingRecord
  belongs_to :preference, class_name: "ComPreference", inverse_of: :com_preference_r18_display_stopper
  belongs_to :option,
             class_name: "ComPreferenceR18DisplayStopperOption",
             inverse_of: :com_preference_r18_display_stoppers

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def enabled? = option_id == ComPreferenceR18DisplayStopperOption::ENABLED

  private

  def set_option_id
    self.option_id ||= ComPreferenceR18DisplayStopperOption::DISABLED
  end
end
