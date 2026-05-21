# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_occurrences
# Database name: occurrence
#
#  id           :bigint           not null, primary key
#  body         :string           default(""), not null
#  context      :jsonb            not null
#  discarded_at :datetime         default(Infinity), not null
#  event_type   :string           default(""), not null
#  memo         :string           default(""), not null
#  purged_at    :datetime         default(Infinity), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public_id    :string(21)       default(""), not null
#  status_id    :bigint           default(1), not null
#
# Indexes
#
#  index_operator_occurrences_on_body                       (body) UNIQUE
#  index_operator_occurrences_on_event_type_and_created_at  (event_type,created_at)
#  index_operator_occurrences_on_public_id                  (public_id) UNIQUE
#  index_operator_occurrences_on_purged_at                  (purged_at)
#  index_operator_occurrences_on_status_id_and_created_at   (status_id,created_at)
#
# Foreign Keys
#
#  fk_staff_occurrences_on_status_id  (status_id => operator_occurrence_statuses.id)
#

require "test_helper"

class OperatorOccurrenceTest < ActiveSupport::TestCase
  test "lifecycle timestamps default" do
    record = build_occurrence(OperatorOccurrence, body: "staff-occur-1", public_id: "Y" * 21)

    assert_occurrence_lifecycle_defaults(record)
  end
end
