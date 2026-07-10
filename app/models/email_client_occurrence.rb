# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: email_client_occurrences
# Database name: occurrence
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  email_occurrence_id :bigint           not null
#  user_occurrence_id  :bigint           not null
#
# Indexes
#
#  idx_email_user_occ_on_ids                             (email_occurrence_id,user_occurrence_id) UNIQUE
#  index_email_client_occurrences_on_user_occurrence_id  (user_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (email_occurrence_id => email_occurrences.id)
#  fk_rails_...  (user_occurrence_id => client_occurrences.id)
#

class EmailClientOccurrence < OccurrenceRecord
  belongs_to :email_occurrence, inverse_of: :email_user_occurrences
  belongs_to :user_occurrence, class_name: "ClientOccurrence"

  validates :email_occurrence_id, uniqueness: { scope: :user_occurrence_id }
end
