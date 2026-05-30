# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_adult_content_gates
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
#  index_client_preference_adult_content_gates_on_option_id      (option_id)
#  index_client_preference_adult_content_gates_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (option_id => client_preference_adult_content_gate_options.id)
#  fk_rails_...  (preference_id => client_preferences.id)
#
class ClientPreferenceAdultContentGate < AppPrincipalRecord
  belongs_to :preference, class_name: "ClientPreference", inverse_of: :client_preference_adult_content_gate
  belongs_to :option,
             class_name: "ClientPreferenceAdultContentGateOption",
             inverse_of: :client_preference_adult_content_gates

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def approved? = option_id == ClientPreferenceAdultContentGateOption::APPROVED

  def denied? = option_id == ClientPreferenceAdultContentGateOption::DENY

  def enabled? = denied?

  private

  def set_option_id
    self.option_id ||= ClientPreferenceAdultContentGateOption::NOTHING
  end
end
