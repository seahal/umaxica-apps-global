# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_preferences
# Database name: operator
#
#  id              :bigint           not null, primary key
#  consent_version :uuid
#  consented       :boolean          default(FALSE), not null
#  consented_at    :datetime
#  functional      :boolean          default(FALSE), not null
#  language        :string           default("ja"), not null
#  performant      :boolean          default(FALSE), not null
#  region          :string           default("jp"), not null
#  targetable      :boolean          default(FALSE), not null
#  theme           :string           default("sy"), not null
#  timezone        :string           default("Asia/Tokyo"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  staff_id        :bigint           not null
#
# Indexes
#
#  index_staff_preferences_on_staff_id  (staff_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => staffs.id)
#
class StaffPreference < OperatorRecord
  belongs_to :staff, inverse_of: :staff_preference

  has_one :staff_preference_language,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :staff_preference_timezone,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :staff_preference_region,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy
  has_one :staff_preference_theme,
          foreign_key: :preference_id,
          inverse_of: :preference,
          dependent: :destroy

  validates :staff_id, uniqueness: true
  validates :consented, inclusion: { in: [true, false] }
  validates :functional, inclusion: { in: [true, false] }
  validates :performant, inclusion: { in: [true, false] }
  validates :targetable, inclusion: { in: [true, false] }

  after_initialize :set_defaults

  private

  def set_defaults
    return unless new_record?

    self.consented = false if consented.nil?
    self.functional = false if functional.nil?
    self.performant = false if performant.nil?
    self.targetable = false if targetable.nil?
  end
end
