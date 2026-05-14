# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: area_staff_occurrences
# Database name: occurrence
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  area_occurrence_id  :bigint           not null
#  staff_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_area_staff_occ_on_ids                            (area_occurrence_id,staff_occurrence_id) UNIQUE
#  index_area_staff_occurrences_on_staff_occurrence_id  (staff_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (area_occurrence_id => area_occurrences.id)
#  fk_rails_...  (staff_occurrence_id => staff_occurrences.id)
#

class AreaOperatorOccurrence < OccurrenceRecord
  self.table_name = "area_staff_occurrences"
  belongs_to :area_occurrence, inverse_of: :area_staff_occurrences
  belongs_to :staff_occurrence, class_name: "OperatorOccurrence", inverse_of: :area_staff_occurrences

  validates :area_occurrence_id, uniqueness: { scope: :staff_occurrence_id }
end
