# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_motions
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
#  index_org_preference_motions_on_option_id      (option_id)
#  index_org_preference_motions_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (option_id => org_preference_motion_options.id)
#  fk_rails_...  (preference_id => org_preferences.id)
#
class OrgPreferenceMotion < OrgSettingRecord
  belongs_to :preference, class_name: "OrgPreference", inverse_of: :org_preference_motion
  belongs_to :option,
             class_name: "OrgPreferenceMotionOption",
             inverse_of: :org_preference_motions

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= OrgPreferenceMotionOption::STANDARD
  end
end
