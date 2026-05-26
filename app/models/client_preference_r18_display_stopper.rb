# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_r18_display_stoppers
# Database name: app_principal
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_client_preference_r18_display_stoppers_on_option_id      (option_id)
#  index_client_preference_r18_display_stoppers_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (option_id => client_preference_r18_display_stopper_options.id)
#  fk_rails_...  (preference_id => client_preferences.id)
#
class ClientPreferenceR18DisplayStopper < AppPrincipalRecord
  belongs_to :preference, class_name: "ClientPreference", inverse_of: :client_preference_r18_display_stopper
  belongs_to :option,
             class_name: "ClientPreferenceR18DisplayStopperOption",
             inverse_of: :client_preference_r18_display_stoppers

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def approved? = option_id == ClientPreferenceR18DisplayStopperOption::APPROVED

  def denied? = option_id == ClientPreferenceR18DisplayStopperOption::DENY

  def enabled? = denied?

  private

  def set_option_id
    self.option_id ||= ClientPreferenceR18DisplayStopperOption::NOTHING
  end
end
