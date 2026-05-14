# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_telephone_occurrences
# Database name: occurrence
#
#  id                      :bigint           not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  staff_occurrence_id     :bigint           not null
#  telephone_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_staff_telephone_occ_on_ids                                (staff_occurrence_id,telephone_occurrence_id) UNIQUE
#  index_staff_telephone_occurrences_on_telephone_occurrence_id  (telephone_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_occurrence_id => staff_occurrences.id)
#  fk_rails_...  (telephone_occurrence_id => telephone_occurrences.id)
#

class OperatorTelephoneOccurrence < OccurrenceRecord
  self.table_name = "staff_telephone_occurrences"
  belongs_to :staff_occurrence, class_name: "OperatorOccurrence", inverse_of: :staff_telephone_occurrences
  belongs_to :telephone_occurrence, inverse_of: :staff_telephone_occurrences

  validates :staff_occurrence_id, uniqueness: { scope: :telephone_occurrence_id }
end
