# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_densities
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
#  index_com_preference_densities_on_option_id      (option_id)
#  index_com_preference_densities_on_preference_id  (preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (option_id => com_preference_density_options.id)
#  fk_rails_...  (preference_id => com_preferences.id)
#
class ComPreferenceDensity < ComSettingRecord
  belongs_to :preference, class_name: "ComPreference", inverse_of: :com_preference_density
  belongs_to :option,
             class_name: "ComPreferenceDensityOption",
             inverse_of: :com_preference_densities

  validates :preference_id, uniqueness: true

  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= ComPreferenceDensityOption::STANDARD
  end
end
