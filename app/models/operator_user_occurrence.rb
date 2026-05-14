# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_user_occurrences
# Database name: occurrence
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  staff_occurrence_id :bigint           not null
#  user_occurrence_id  :bigint           not null
#
# Indexes
#
#  idx_staff_user_occ_on_ids                           (staff_occurrence_id,user_occurrence_id) UNIQUE
#  index_staff_user_occurrences_on_user_occurrence_id  (user_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_occurrence_id => staff_occurrences.id)
#  fk_rails_...  (user_occurrence_id => user_occurrences.id)
#

class OperatorUserOccurrence < OccurrenceRecord
  self.table_name = "staff_user_occurrences"
  belongs_to :staff_occurrence, class_name: "OperatorOccurrence", inverse_of: :staff_user_occurrences
  belongs_to :user_occurrence, inverse_of: :staff_user_occurrences

  validates :staff_occurrence_id, uniqueness: { scope: :user_occurrence_id }
end
