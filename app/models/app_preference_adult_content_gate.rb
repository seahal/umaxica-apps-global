# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_adult_content_gates
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
#  index_app_preference_adult_content_gates_on_option_id      (option_id)
#  index_app_preference_adult_content_gates_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (option_id => app_preference_adult_content_gate_options.id)
#  fk_rails_...  (preference_id => app_preferences.id)
#
class AppPreferenceAdultContentGate < AppSettingRecord
  belongs_to :preference, class_name: "AppPreference", inverse_of: :app_preference_adult_content_gate
  belongs_to :option,
             class_name: "AppPreferenceAdultContentGateOption",
             inverse_of: :app_preference_adult_content_gates

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def approved? = option_id == AppPreferenceAdultContentGateOption::APPROVED

  def denied? = option_id == AppPreferenceAdultContentGateOption::DENY

  def enabled? = denied?

  private

  def set_option_id
    self.option_id ||= AppPreferenceAdultContentGateOption::NOTHING
  end
end
