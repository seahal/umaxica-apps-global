# typed: false
# frozen_string_literal: true

class VisitorPreferenceR18DisplayStopper < ComPrincipalRecord
  belongs_to :preference, class_name: "VisitorPreference", inverse_of: :visitor_preference_r18_display_stopper
  belongs_to :option,
             class_name: "VisitorPreferenceR18DisplayStopperOption",
             inverse_of: :visitor_preference_r18_display_stoppers

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def enabled? = option_id == VisitorPreferenceR18DisplayStopperOption::ENABLED

  private

  def set_option_id
    self.option_id ||= VisitorPreferenceR18DisplayStopperOption::DISABLED
  end
end
