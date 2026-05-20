# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOutCycleTest < ActiveSupport::TestCase
  SIGN_OUT_CLASSES = [
    ClientSignOutCycle,
    VisitorSignOutCycle,
    OperatorSignOutCycle,
  ].freeze

  test "sign-out cycles inherit from their surface cycle records" do
    assert_operator ClientSignOutCycle, :<, AppTicketRecord
    assert_operator VisitorSignOutCycle, :<, ComTicketRecord
    assert_operator OperatorSignOutCycle, :<, OrgTicketRecord
  end

  test "sign-out status reference tables include nothing as the zero value" do
    SIGN_OUT_CLASSES.each do |cycle_class|
      assert_equal 0, cycle_class::STATUS_MODEL::NOTHING
      assert_includes cycle_class::STATUS_MODEL::DEFAULTS, cycle_class::STATUS_MODEL::NOTHING
      assert_includes cycle_class::STATUS_IDS, cycle_class::STATUS_MODEL::NOTHING
    end
  end

  test "sign-out kind reference tables include nothing as the zero value" do
    SIGN_OUT_CLASSES.each do |cycle_class|
      assert_equal 0, cycle_class::KIND_MODEL::NOTHING
      assert_includes cycle_class::KIND_MODEL::DEFAULTS, cycle_class::KIND_MODEL::NOTHING
      assert_equal cycle_class::KIND_MODEL::NOTHING, cycle_class.default_kind_id
    end
  end

  test "sign-out cycles default to requested status and nothing kind" do
    SIGN_OUT_CLASSES.each do |cycle_class|
      cycle = build_cycle(cycle_class)

      assert_predicate cycle, :valid?, cycle.errors.full_messages.join(", ")
      assert_equal cycle_class::STATUS_MODEL::REQUESTED, cycle.status_id
      assert_equal cycle_class::KIND_MODEL::NOTHING, cycle.kind_id
    end
  end

  test "sign-out cycles reject unknown statuses and kinds" do
    SIGN_OUT_CLASSES.each do |cycle_class|
      invalid_status = build_cycle(cycle_class, status_id: 999)

      assert_not invalid_status.valid?, cycle_class.name
      assert_not_empty invalid_status.errors[:status_id]

      invalid_kind = build_cycle(cycle_class, kind_id: 999)

      assert_not invalid_kind.valid?, cycle_class.name
      assert_not_empty invalid_kind.errors[:kind_id]
    end
  end

  test "sign-out cycles require refresh expiry at or after access expiry" do
    cycle = build_cycle(
      ClientSignOutCycle,
      access_expires_at: Time.zone.local(2026, 5, 19, 11, 0, 0),
      refresh_expires_at: Time.zone.local(2026, 5, 19, 10, 59, 59),
    )

    assert_not cycle.valid?
    assert_not_empty cycle.errors[:refresh_expires_at]
  end

  test "sign-out cycle methods progress through the logout boundary states" do
    now = Time.zone.local(2026, 5, 19, 11, 0, 0)
    cycle = ClientSignOutCycle.create!(cycle_attrs(ClientSignOutCycle))

    travel_to now do
      cycle.mark_access_discarded!

      assert_predicate cycle, :sign_out_access_discarded?
      assert_equal now, cycle.access_discarded_at

      cycle.mark_logically_revoked!

      assert_predicate cycle, :sign_out_logically_revoked?
      assert_equal now, cycle.logically_revoked_at

      cycle.await_sign_out_expiry!

      assert_predicate cycle, :sign_out_awaiting_expiry?

      cycle.complete_sign_out!

      assert_predicate cycle, :sign_out_completed?
      assert_equal now, cycle.completed_at
    end
  end

  test "sign-out cycle methods reject reverse transitions through Cycle::Base" do
    cycle = ClientSignOutCycle.create!(cycle_attrs(ClientSignOutCycle))
    cycle.mark_access_discarded!

    error =
      assert_raises(Cycle::InvalidTransition) do
        cycle.transition_cycle_to!(
          ClientSignOutCycleStatus::REQUESTED,
          allowed_from: [ClientSignOutCycleStatus::REQUESTED],
        )
      end

    assert_match(/invalid transition/, error.message)
    assert_equal ClientSignOutCycleStatus::ACCESS_DISCARDED, cycle.reload.status_id
  end

  test "sign-out cycles can fail before completion" do
    now = Time.zone.local(2026, 5, 19, 11, 0, 0)
    cycle = ClientSignOutCycle.create!(cycle_attrs(ClientSignOutCycle))

    travel_to now do
      cycle.fail_sign_out!
    end

    assert_predicate cycle, :sign_out_failed?
    assert_equal now, cycle.failed_at
  end

  private

  def build_cycle(cycle_class, **overrides)
    cycle_class.new(cycle_attrs(cycle_class).merge(overrides))
  end

  def cycle_attrs(cycle_class)
    {
      principal_id: 123,
      status_id: cycle_class.default_status_id,
      kind_id: cycle_class.default_kind_id,
      refresh_token_family_id: "family-#{cycle_class.name}",
      requested_at: Time.current,
      access_expires_at: 5.minutes.from_now,
      refresh_expires_at: 1.hour.from_now,
      return_to: "/dashboard",
    }
  end
end
