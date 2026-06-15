# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: account_access_events
# Database name: chronicle
#
#  id                    :bigint           not null, primary key
#  account_type          :string           not null
#  event_type            :string           not null
#  metadata              :jsonb            not null
#  next_access_state     :string           not null
#  occurred_at           :datetime         not null
#  previous_access_state :string           not null
#  reason_code           :string           not null
#  reason_note           :text
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  operator_id           :bigint           not null
#  ticket_id             :string
#
# Indexes
#
#  idx_on_account_type_account_id_occurred_at_950619886b  (account_type,account_id,occurred_at)
#  index_account_access_events_on_event_type              (event_type)
#  index_account_access_events_on_operator_id             (operator_id)
#  index_account_access_events_on_reason_code             (reason_code)
#  index_account_access_events_on_ticket_id               (ticket_id)
#
require "test_helper"

class AccountAccessEventTest < ActiveSupport::TestCase
  test "accepts session revocation event types" do
    operator = operators(:one)
    client = clients(:one)

    event = AccountAccessEvent.new(
      account_type: "Client",
      account_id: client.id,
      event_type: AccountAccessEvent::EVENT_TYPE_EMERGENCY_SESSION_REVOKE,
      previous_access_state: client.access_state,
      next_access_state: client.access_state,
      operator_id: operator.id,
      reason_code: "security_incident",
      occurred_at: Time.current,
      metadata: {},
    )

    assert_predicate event, :valid?
    assert event.save
  end

  test "rejects unknown event types" do
    operator = operators(:one)
    client = clients(:one)

    event = AccountAccessEvent.new(
      account_type: "Client",
      account_id: client.id,
      event_type: "unknown_session_action",
      previous_access_state: client.access_state,
      next_access_state: client.access_state,
      operator_id: operator.id,
      reason_code: "security_incident",
      occurred_at: Time.current,
      metadata: {},
    )

    assert_predicate event, :invalid?
    assert_not_empty event.errors[:event_type]
  end
end
