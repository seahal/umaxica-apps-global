# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_r18_display_stoppers
# Database name: org_principal
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  idx_on_preference_id_7d925420d9                              (preference_id) UNIQUE
#  index_operator_preference_r18_display_stoppers_on_option_id  (option_id)
#
# Foreign Keys
#
#  fk_rails_...  (option_id => operator_preference_r18_display_stopper_options.id)
#  fk_rails_...  (preference_id => operator_preferences.id)
#
class OperatorPreferenceR18DisplayStopper < OrgPrincipalRecord
  belongs_to :preference, class_name: "OperatorPreference", inverse_of: :operator_preference_r18_display_stopper
  belongs_to :option,
             class_name: "OperatorPreferenceR18DisplayStopperOption",
             inverse_of: :operator_preference_r18_display_stoppers

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def approved? = option_id == OperatorPreferenceR18DisplayStopperOption::APPROVED

  def denied? = option_id == OperatorPreferenceR18DisplayStopperOption::DENY

  def enabled? = denied?

  private

  def set_option_id
    self.option_id ||= OperatorPreferenceR18DisplayStopperOption::NOTHING
  end
end
