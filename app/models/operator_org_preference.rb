# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_org_preferences
# Database name: operator
#
#  id                :bigint           not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  org_preference_id :bigint           not null
#  staff_id          :bigint           not null
#
# Indexes
#
#  index_staff_org_preferences_on_org_preference_id               (org_preference_id)
#  index_staff_org_preferences_on_staff_id_and_org_preference_id  (staff_id,org_preference_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (org_preference_id => org_preferences.id) ON DELETE => cascade
#  fk_rails_...  (staff_id => operators.id)
#
class OperatorOrgPreference < OperatorRecord
  self.table_name = "staff_org_preferences"
  belongs_to :staff, class_name: "Operator"
  belongs_to :org_preference

  validates :staff_id, uniqueness: { scope: :org_preference_id }
end
