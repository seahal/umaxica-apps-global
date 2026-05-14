# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: email_staff_occurrences
# Database name: occurrence
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  email_occurrence_id :bigint           not null
#  staff_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_email_staff_occ_on_ids                            (email_occurrence_id,staff_occurrence_id) UNIQUE
#  index_email_staff_occurrences_on_staff_occurrence_id  (staff_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (email_occurrence_id => email_occurrences.id)
#  fk_rails_...  (staff_occurrence_id => staff_occurrences.id)
#

class EmailOperatorOccurrence < OccurrenceRecord
  self.table_name = "email_staff_occurrences"
  belongs_to :email_occurrence, inverse_of: :email_staff_occurrences
  belongs_to :staff_occurrence, class_name: "OperatorOccurrence", inverse_of: :email_staff_occurrences

  validates :email_occurrence_id, uniqueness: { scope: :staff_occurrence_id }
end
