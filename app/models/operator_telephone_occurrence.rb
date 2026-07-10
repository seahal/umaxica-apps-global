# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_telephone_occurrences
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
#  idx_on_telephone_occurrence_id_de4dc4cae4  (telephone_occurrence_id)
#  idx_staff_telephone_occ_on_ids             (staff_occurrence_id,telephone_occurrence_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_occurrence_id => operator_occurrences.id)
#  fk_rails_...  (telephone_occurrence_id => telephone_occurrences.id)
#

class OperatorTelephoneOccurrence < OccurrenceRecord
  belongs_to :staff_occurrence, class_name: "OperatorOccurrence", inverse_of: :staff_telephone_occurrences
  belongs_to :telephone_occurrence, inverse_of: :staff_telephone_occurrences

  validates :staff_occurrence_id, uniqueness: { scope: :telephone_occurrence_id }
end
