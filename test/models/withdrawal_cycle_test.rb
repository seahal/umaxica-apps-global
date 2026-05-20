# typed: false
# frozen_string_literal: true

require "test_helper"

class WithdrawalCycleTest < ActiveSupport::TestCase
  CYCLE_CLASSES = [
    ClientWithdrawalCycle,
    VisitorWithdrawalCycle,
  ].freeze

  test "withdrawal status reference tables use the agreed fixed ids" do
    CYCLE_CLASSES.each do |cycle_class|
      assert_equal 0, cycle_class::STATUS_MODEL::NOTHING
      assert_equal 10, cycle_class::STATUS_MODEL::REQUESTED
      assert_equal 20, cycle_class::STATUS_MODEL::CLOSING
      assert_equal 30, cycle_class::STATUS_MODEL::DISCARDED
      assert_equal 40, cycle_class::STATUS_MODEL::RECOVERED
      assert_equal 100, cycle_class::STATUS_MODEL::TERMINATED
      assert_equal 900, cycle_class::STATUS_MODEL::FAILED
      assert_equal [0, 10, 20, 30, 40, 100, 900], cycle_class::STATUS_MODEL::DEFAULTS
    end
  end

  test "withdrawal cycles default to requested and record the initial event" do
    cycle = ClientWithdrawalCycle.create!(client: create_client)

    assert_predicate cycle, :withdrawal_requested?
    assert_equal ClientWithdrawalCycleStatus::REQUESTED, cycle.status_id

    event = cycle.client_withdrawal_cycle_events.sole

    assert_equal ClientWithdrawalCycleStatus::NOTHING, event.from_status_id
    assert_equal ClientWithdrawalCycleStatus::REQUESTED, event.to_status_id
    assert_equal cycle.client_id, event.client_id
    assert_in_delta cycle.began_at.to_f, event.occurred_at.to_f, 0.001
  end

  test "withdrawal cycle methods progress through closing and discarded states with events" do
    now = Time.zone.local(2026, 5, 19, 12, 0, 0)

    cycle = nil
    travel_to now do
      cycle = ClientWithdrawalCycle.create!(client: create_client)
      cycle.confirm_withdrawal!(token_public_id: "token-one", reason: "confirmed")
      cycle.discard_withdrawal!(token_public_id: "token-one", reason: "finalized")
    end

    cycle.reload

    assert_predicate cycle, :withdrawal_discarded?

    events = cycle.client_withdrawal_cycle_events.order(:occurred_at, :id).to_a

    assert_equal 3, events.size
    assert_equal ClientWithdrawalCycleStatus::CLOSING, events.second.to_status_id
    assert_equal "confirmed", events.second.reason
    assert_equal "token-one", events.second.token_public_id
    assert_equal ClientWithdrawalCycleStatus::DISCARDED, events.third.to_status_id
  end

  test "withdrawal recovery completes the cycle and records completion time" do
    now = Time.zone.local(2026, 5, 19, 12, 0, 0)
    cycle = ClientWithdrawalCycle.create!(client: create_client)
    cycle.confirm_withdrawal!
    cycle.discard_withdrawal!

    travel_to now do
      cycle.recover_withdrawal!(reason: "recovered")
    end

    cycle.reload

    assert_predicate cycle, :withdrawal_recovered?
    assert_equal now, cycle.completed_at

    event = cycle.client_withdrawal_cycle_events.order(:id).last

    assert_equal ClientWithdrawalCycleStatus::RECOVERED, event.to_status_id
    assert_equal "recovered", event.reason
  end

  test "withdrawal termination completes the cycle" do
    now = Time.zone.local(2026, 5, 19, 12, 0, 0)
    cycle = VisitorWithdrawalCycle.create!(visitor: create_visitor)
    cycle.confirm_withdrawal!
    cycle.discard_withdrawal!

    travel_to now do
      cycle.terminate_withdrawal!(reason: "purged")
    end

    cycle.reload

    assert_predicate cycle, :withdrawal_terminated?
    assert_equal now, cycle.completed_at

    event = cycle.visitor_withdrawal_cycle_events.order(:id).last

    assert_equal VisitorWithdrawalCycleStatus::TERMINATED, event.to_status_id
    assert_equal "purged", event.reason
  end

  test "withdrawal transitions reject reverse movement" do
    cycle = ClientWithdrawalCycle.create!(client: create_client)
    cycle.confirm_withdrawal!

    error =
      assert_raises(Cycle::InvalidTransition) do
        cycle.request_withdrawal!
      end

    assert_match(/invalid transition/, error.message)
    assert_equal ClientWithdrawalCycleStatus::CLOSING, cycle.reload.status_id
  end

  test "terminal and failed statuses require terminal timestamps" do
    recovered = ClientWithdrawalCycle.new(
      client: create_client,
      status_id: ClientWithdrawalCycleStatus::RECOVERED,
    )

    assert_not recovered.valid?
    assert_not_empty recovered.errors[:completed_at]

    failed = VisitorWithdrawalCycle.new(
      visitor: create_visitor,
      status_id: VisitorWithdrawalCycleStatus::FAILED,
    )

    assert_not failed.valid?
    assert_not_empty failed.errors[:failed_at]
  end

  private

  def create_client
    ClientStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientMultiFactor.ensure_defaults!
    ClientMultiFactorStatus.ensure_defaults!

    Client.create!(
      public_id: "client_#{SecureRandom.hex(7)}",
      status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
      multi_factor_id: ClientMultiFactor::NOTHING,
      multi_factor_status_id: ClientMultiFactorStatus::UNCONFIGURED,
    )
  end

  def create_visitor
    VisitorStatus.ensure_defaults!
    VisitorVisibility.ensure_defaults!
    VisitorMultiFactor.ensure_defaults!
    VisitorMultiFactorStatus.ensure_defaults!

    Visitor.create!(
      public_id: "visitor_#{SecureRandom.hex(6)}",
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
      multi_factor_id: VisitorMultiFactor::NOTHING,
      multi_factor_status_id: VisitorMultiFactorStatus::UNCONFIGURED,
    )
  end
end
