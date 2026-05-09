# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_preference_regions
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
#  index_customer_preference_regions_on_option_id      (option_id)
#  index_customer_preference_regions_on_preference_id  (preference_id) UNIQUE
#
class CustomerPreferenceRegion < SettingRecord
  belongs_to :preference, class_name: "CustomerPreference", inverse_of: :customer_preference_region
  belongs_to :option,
             class_name: "CustomerPreferenceRegionOption",
             inverse_of: :customer_preference_regions,
             optional: true

  validates :preference_id, uniqueness: true
  validates :option_id, presence: true

  before_validation :set_option_id

  private

  def set_option_id
    self.option_id ||= CustomerPreferenceRegionOption::JP
  end
end
