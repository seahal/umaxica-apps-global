# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_adult_content_gates
# Database name: org_setting
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_org_preference_adult_content_gates_on_option_id      (option_id)
#  index_org_preference_adult_content_gates_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (option_id => org_preference_adult_content_gate_options.id)
#  fk_rails_...  (preference_id => org_preferences.id)
#
class OrgPreferenceAdultContentGate < OrgSettingRecord
  belongs_to :preference, class_name: "OrgPreference", inverse_of: :org_preference_adult_content_gate
  belongs_to :option,
             class_name: "OrgPreferenceAdultContentGateOption",
             inverse_of: :org_preference_adult_content_gates

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def approved? = option_id == OrgPreferenceAdultContentGateOption::APPROVED

  def denied? = option_id == OrgPreferenceAdultContentGateOption::DENY

  def enabled? = denied?

  private

  def set_option_id
    self.option_id ||= OrgPreferenceAdultContentGateOption::NOTHING
  end
end
