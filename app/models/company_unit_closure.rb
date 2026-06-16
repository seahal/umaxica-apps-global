# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: company_unit_closures
# Database name: com_zenith
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
#  idx_company_unit_closures_unique_path         (ancestor_id,descendant_id) UNIQUE
#  index_company_unit_closures_on_ancestor_id    (ancestor_id)
#  index_company_unit_closures_on_descendant_id  (descendant_id)
#
# Foreign Keys
#
#  fk_rails_...  (ancestor_id => company_units.id)
#  fk_rails_...  (descendant_id => company_units.id)
#
class CompanyUnitClosure < ComRpRecord
  belongs_to :ancestor,
             class_name: "CompanyUnit",
             inverse_of: :descendant_links
  belongs_to :descendant,
             class_name: "CompanyUnit",
             inverse_of: :ancestor_links

  validates :depth, presence: true
  validates :depth, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :ancestor_id, uniqueness: { scope: :descendant_id }
end
