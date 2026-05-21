# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: telephone_client_occurrences
# Database name: occurrence
#
#  id                      :bigint           not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  telephone_occurrence_id :bigint           not null
#  user_occurrence_id      :bigint           not null
#
# Indexes
#
#  idx_telephone_user_occ_on_ids                             (telephone_occurrence_id,user_occurrence_id) UNIQUE
#  index_telephone_client_occurrences_on_user_occurrence_id  (user_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (telephone_occurrence_id => telephone_occurrences.id)
#  fk_rails_...  (user_occurrence_id => client_occurrences.id)
#

class TelephoneClientOccurrence < OccurrenceRecord
  belongs_to :telephone_occurrence, inverse_of: :telephone_user_occurrences
  belongs_to :user_occurrence, class_name: "ClientOccurrence"

  validates :telephone_occurrence_id, uniqueness: { scope: :user_occurrence_id }
end
