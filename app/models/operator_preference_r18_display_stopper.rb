# typed: false
# frozen_string_literal: true

class OperatorPreferenceR18DisplayStopper < OrgPrincipalRecord
  belongs_to :preference, class_name: "OperatorPreference", inverse_of: :operator_preference_r18_display_stopper
  belongs_to :option,
             class_name: "OperatorPreferenceR18DisplayStopperOption",
             inverse_of: :operator_preference_r18_display_stoppers

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def enabled? = option_id == OperatorPreferenceR18DisplayStopperOption::ENABLED

  private

  def set_option_id
    self.option_id ||= OperatorPreferenceR18DisplayStopperOption::DISABLED
  end
end
