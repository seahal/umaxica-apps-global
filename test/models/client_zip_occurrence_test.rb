# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_zip_occurrences
# Database name: occurrence
#
#  id                 :bigint           not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_occurrence_id :bigint           not null
#  zip_occurrence_id  :bigint           not null
#
# Indexes
#
#  idx_user_zip_occ_on_ids                          (user_occurrence_id,zip_occurrence_id) UNIQUE
#  index_user_zip_occurrences_on_zip_occurrence_id  (zip_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_occurrence_id => user_occurrences.id)
#  fk_rails_...  (zip_occurrence_id => zip_occurrences.id)
#

require "test_helper"

class ClientZipOccurrenceTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "ClientZipOccurrence", ClientZipOccurrence.name
  end
end
