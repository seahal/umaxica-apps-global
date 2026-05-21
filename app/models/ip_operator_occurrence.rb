# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_operator_occurrences
# Database name: occurrence
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  ip_occurrence_id    :bigint           not null
#  staff_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_ip_staff_occ_on_ids                               (ip_occurrence_id,staff_occurrence_id) UNIQUE
#  index_ip_operator_occurrences_on_staff_occurrence_id  (staff_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (ip_occurrence_id => ip_occurrences.id)
#  fk_rails_...  (staff_occurrence_id => operator_occurrences.id)
#

class IpOperatorOccurrence < OccurrenceRecord
  belongs_to :ip_occurrence, inverse_of: :ip_staff_occurrences
  belongs_to :staff_occurrence, class_name: "OperatorOccurrence", inverse_of: :ip_staff_occurrences

  validates :ip_occurrence_id, uniqueness: { scope: :staff_occurrence_id }
end
