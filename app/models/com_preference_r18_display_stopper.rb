# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_r18_display_stoppers
# Database name: com_setting
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_com_preference_r18_display_stoppers_on_option_id      (option_id)
#  index_com_preference_r18_display_stoppers_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (option_id => com_preference_r18_display_stopper_options.id)
#  fk_rails_...  (preference_id => com_preferences.id)
#
class ComPreferenceR18DisplayStopper < ComSettingRecord
  belongs_to :preference, class_name: "ComPreference", inverse_of: :com_preference_r18_display_stopper
  belongs_to :option,
             class_name: "ComPreferenceR18DisplayStopperOption",
             inverse_of: :com_preference_r18_display_stoppers

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  def approved? = option_id == ComPreferenceR18DisplayStopperOption::APPROVED

  def denied? = option_id == ComPreferenceR18DisplayStopperOption::DENY

  def enabled? = denied?

  private

  def set_option_id
    self.option_id ||= ComPreferenceR18DisplayStopperOption::NOTHING
  end
end
