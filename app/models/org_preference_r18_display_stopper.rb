# typed: false
# frozen_string_literal: true

class OrgPreferenceR18DisplayStopper < OrgSettingRecord
  belongs_to :preference, class_name: "OrgPreference", inverse_of: :org_preference_r18_display_stopper
  belongs_to :option,
             class_name: "OrgPreferenceR18DisplayStopperOption",
             inverse_of: :org_preference_r18_display_stoppers

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def enabled? = option_id == OrgPreferenceR18DisplayStopperOption::ENABLED

  private

  def set_option_id
    self.option_id ||= OrgPreferenceR18DisplayStopperOption::DISABLED
  end
end
