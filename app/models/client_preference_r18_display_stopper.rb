# typed: false
# frozen_string_literal: true

class ClientPreferenceR18DisplayStopper < AppPrincipalRecord
  belongs_to :preference, class_name: "ClientPreference", inverse_of: :client_preference_r18_display_stopper
  belongs_to :option,
             class_name: "ClientPreferenceR18DisplayStopperOption",
             inverse_of: :client_preference_r18_display_stoppers

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def enabled? = option_id == ClientPreferenceR18DisplayStopperOption::ENABLED

  private

  def set_option_id
    self.option_id ||= ClientPreferenceR18DisplayStopperOption::DISABLED
  end
end
