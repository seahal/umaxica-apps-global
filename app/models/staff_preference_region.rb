# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_preference_regions
# Database name: operator
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  option_id     :bigint           not null
#  preference_id :bigint           not null
#
# Indexes
#
#  index_staff_preference_regions_on_option_id      (option_id)
#  index_staff_preference_regions_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_staff_preference_regions_on_option_id      (option_id => staff_preference_region_options.id)
#  fk_staff_preference_regions_on_preference_id  (preference_id => staff_preferences.id)
#
class StaffPreferenceRegion < OperatorRecord
  belongs_to :preference, class_name: "StaffPreference", inverse_of: :staff_preference_region
  belongs_to :option,
             class_name: "StaffPreferenceRegionOption",
             inverse_of: :staff_preference_regions,
             optional: true
  validates :preference_id, uniqueness: true
  validates :option_id, presence: true
  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= StaffPreferenceRegionOption::JP
  end
end
