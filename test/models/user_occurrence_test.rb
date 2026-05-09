# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_occurrences
# Database name: occurrence
#
#  id         :bigint           not null, primary key
#  body       :string           default(""), not null
#  context    :jsonb            not null
#  event_type :string           default(""), not null
#  lapses_at  :datetime         default(Infinity), not null
#  memo       :string           default(""), not null
#  purge_at   :datetime         default(Infinity), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string(21)       default(""), not null
#  status_id  :bigint           default(0), not null
#
# Indexes
#
#  index_user_occurrences_on_body                       (body) UNIQUE
#  index_user_occurrences_on_event_type_and_created_at  (event_type,created_at)
#  index_user_occurrences_on_public_id                  (public_id) UNIQUE
#  index_user_occurrences_on_purge_at                   (purge_at)
#  index_user_occurrences_on_status_id_and_created_at   (status_id,created_at)
#
# Foreign Keys
#
#  fk_user_occurrences_on_status_id  (status_id => user_occurrence_statuses.id)
#

require "test_helper"

class UserOccurrenceTest < ActiveSupport::TestCase
  test "defaults status_id to nothing" do
    record = build_occurrence(UserOccurrence, body: "user-occur-2", public_id: "X" * 21)

    assert_equal UserOccurrenceStatus::NOTHING, record.status_id
  end

  test "lifecycle timestamps default" do
    record = build_occurrence(UserOccurrence, body: "user-occur-1", public_id: "Y" * 21)

    assert_occurrence_lifecycle_defaults(record)
  end
end
