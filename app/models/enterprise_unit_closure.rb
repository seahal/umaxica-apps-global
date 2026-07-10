# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: enterprise_unit_closures
# Database name: app_zenith
#
#  id            :bigint           not null, primary key
#  depth         :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ancestor_id   :bigint           not null
#  descendant_id :bigint           not null
#
# Indexes
#
#  idx_enterprise_unit_closures_unique_path         (ancestor_id,descendant_id) UNIQUE
#  index_enterprise_unit_closures_on_descendant_id  (descendant_id)
#
# Foreign Keys
#
#  fk_rails_...  (ancestor_id => enterprise_units.id)
#  fk_rails_...  (descendant_id => enterprise_units.id)
#
class EnterpriseUnitClosure < AppRpRecord
  belongs_to :ancestor,
             class_name: "EnterpriseUnit",
             inverse_of: :descendant_links
  belongs_to :descendant,
             class_name: "EnterpriseUnit",
             inverse_of: :ancestor_links

  validates :depth, presence: true
  validates :depth, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :ancestor_id, uniqueness: { scope: :descendant_id }
end
