# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: chronicle_outbox_entries
# Database name: chronicle
#
#  id           :bigint           not null, primary key
#  event        :string           not null
#  event_uuid   :string           not null
#  payload      :jsonb            not null
#  status       :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  chronicle_id :bigint
#  request_id   :string
#
# Indexes
#
#  index_chronicle_outbox_entries_on_chronicle_id  (chronicle_id)
#  index_chronicle_outbox_entries_on_event_uuid    (event_uuid)
#  index_chronicle_outbox_entries_on_status        (status)
#

require "test_helper"

class ChronicleOutboxEntryTest < ActiveSupport::TestCase
  test "valid with valid attributes" do
    entry = ChronicleOutboxEntry.new(event_uuid: "abc-123", event: "test_event", status: "pending", payload: {})

    assert_predicate entry, :valid?
  end

  test "belongs to chronicle is optional" do
    assert ChronicleOutboxEntry.reflect_on_association(:chronicle).options[:optional]
  end
end
