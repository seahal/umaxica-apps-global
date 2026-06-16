# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: bureau_unit_closures
# Database name: org_zenith
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
#  idx_bureau_unit_closures_unique_path         (ancestor_id,descendant_id) UNIQUE
#  index_bureau_unit_closures_on_ancestor_id    (ancestor_id)
#  index_bureau_unit_closures_on_descendant_id  (descendant_id)
#
# Foreign Keys
#
#  fk_rails_...  (ancestor_id => bureau_units.id)
#  fk_rails_...  (descendant_id => bureau_units.id)
#
class BureauUnitClosure < OrgRpRecord
  belongs_to :ancestor,
             class_name: "BureauUnit",
             inverse_of: :descendant_links
  belongs_to :descendant,
             class_name: "BureauUnit",
             inverse_of: :ancestor_links

  validates :depth, presence: true
  validates :depth, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :ancestor_id, uniqueness: { scope: :descendant_id }
end
