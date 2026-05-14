# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_timezones
# Database name: setting
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_visitor_preference_timezones_on_option_id      (option_id)
#  index_visitor_preference_timezones_on_preference_id  (preference_id) UNIQUE
#
class VisitorPreferenceTimezone < SettingRecord
  belongs_to :preference, class_name: "VisitorPreference", inverse_of: :visitor_preference_timezone
  belongs_to :option,
             class_name: "VisitorPreferenceTimezoneOption",
             inverse_of: :visitor_preference_timezones,
             optional: true

  validates :preference_id, uniqueness: true
  validates :option_id, presence: true

  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= VisitorPreferenceTimezoneOption::ASIA_TOKYO
  end
end
