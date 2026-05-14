# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_staff_occurrences
# Database name: occurrence
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  domain_occurrence_id :bigint           not null
#  staff_occurrence_id  :bigint           not null
#
# Indexes
#
#  idx_domain_staff_occ_on_ids                            (domain_occurrence_id,staff_occurrence_id) UNIQUE
#  index_domain_staff_occurrences_on_staff_occurrence_id  (staff_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (domain_occurrence_id => domain_occurrences.id)
#  fk_rails_...  (staff_occurrence_id => staff_occurrences.id)
#

class DomainOperatorOccurrence < OccurrenceRecord
  self.table_name = "domain_staff_occurrences"
  belongs_to :domain_occurrence, inverse_of: :domain_staff_occurrences
  belongs_to :staff_occurrence, class_name: "OperatorOccurrence", inverse_of: :domain_staff_occurrences

  validates :domain_occurrence_id, uniqueness: { scope: :staff_occurrence_id }
end
