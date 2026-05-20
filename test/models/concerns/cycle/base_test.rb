# typed: false
# frozen_string_literal: true

require "test_helper"

class CycleBaseTest < ActiveSupport::TestCase
  class CycleBaseTestRecord < ApplicationRecord
    self.table_name = "cycle_base_test_records"

    include Cycle::Base

    cycle_status_column :cycle_status_id
  end

  class UnconfiguredCycleBaseTestRecord < ApplicationRecord
    self.table_name = "cycle_base_test_records"

    include Cycle::Base
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:cycle_base_test_records, force: true) do |t|
      t.integer(:cycle_status_id, null: false)
      t.datetime(:discarded_at, null: false)
      t.datetime(:purged_at, null: false)
      t.datetime(:expires_at)
      t.timestamps
    end
    CycleBaseTestRecord.reset_column_information
    UnconfiguredCycleBaseTestRecord.reset_column_information
  end

  teardown do
    @connection.drop_table(:cycle_base_test_records, if_exists: true)
  end

  test "cycle_status_id reads the configured status foreign key" do
    record = build_record(cycle_status_id: 10)

    assert_equal 10, record.cycle_status_id
    assert record.cycle_status?(10)
    assert_not record.cycle_status?(20)
  end

  test "cycle_status_id requires an explicit status column configuration" do
    record = UnconfiguredCycleBaseTestRecord.create!(
      cycle_status_id: 10,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )

    error = assert_raises(Cycle::ConfigurationError) { record.cycle_status_id }

    assert_match(/cycle_status_column/, error.message)
  end

  test "transition_cycle_to updates status when current status is allowed" do
    now = Time.zone.local(2026, 5, 19, 10, 0, 0)
    record = build_record(cycle_status_id: 10, discarded_at: now + 1.day, expires_at: now + 1.hour)

    travel_to now do
      record.transition_cycle_to!(20, allowed_from: [10])
    end

    assert_equal 20, record.reload.cycle_status_id
  end

  test "transition_cycle_to applies additional changes with the status update" do
    now = Time.zone.local(2026, 5, 19, 10, 0, 0)
    record = build_record(cycle_status_id: 10, discarded_at: now + 1.day, expires_at: now + 1.hour)

    travel_to now do
      record.transition_cycle_to!(20, allowed_from: [10], changes: { expires_at: now + 2.hours })
    end

    record.reload

    assert_equal 20, record.cycle_status_id
    assert_equal now + 2.hours, record.expires_at
  end

  test "transition_cycle_to rejects disallowed current status without mutation" do
    now = Time.zone.local(2026, 5, 19, 10, 0, 0)
    record = build_record(cycle_status_id: 10, discarded_at: now + 1.day, expires_at: now + 1.hour)

    travel_to now do
      error =
        assert_raises(Cycle::InvalidTransition) do
          record.transition_cycle_to!(30, allowed_from: [20])
        end

      assert_match(/invalid transition/, error.message)
    end

    assert_equal 10, record.reload.cycle_status_id
  end

  test "transition_cycle_to rejects discarded cycles" do
    now = Time.zone.local(2026, 5, 19, 10, 0, 0)
    record = build_record(cycle_status_id: 10, discarded_at: now, purged_at: now + 1.day)

    travel_to now do
      error =
        assert_raises(Cycle::InvalidTransition) do
          record.transition_cycle_to!(20, allowed_from: [10])
        end

      assert_match(/cycle is discarded/, error.message)
    end

    assert_equal 10, record.reload.cycle_status_id
  end

  test "transition_cycle_to rejects expired cycles" do
    now = Time.zone.local(2026, 5, 19, 10, 0, 0)
    record = build_record(cycle_status_id: 10, discarded_at: now + 1.day, expires_at: now)

    travel_to now do
      error =
        assert_raises(Cycle::InvalidTransition) do
          record.transition_cycle_to!(20, allowed_from: [10])
        end

      assert_match(/cycle is expired/, error.message)
    end

    assert_equal 10, record.reload.cycle_status_id
  end

  test "discard_cycle updates retention timestamps when order is valid" do
    now = Time.zone.local(2026, 5, 19, 10, 0, 0)
    record = build_record(cycle_status_id: 10, discarded_at: now + 1.day, purged_at: now + 2.days)

    travel_to now do
      record.discard_cycle!(discarded_at: now, purged_at: now + 30.days)
    end

    record.reload

    assert_equal now, record.discarded_at
    assert_equal now + 30.days, record.purged_at
  end

  test "discard_cycle rejects retention timestamps out of order" do
    now = Time.zone.local(2026, 5, 19, 10, 0, 0)
    record = build_record(cycle_status_id: 10, discarded_at: now + 1.day, purged_at: now + 2.days)

    error =
      assert_raises(ArgumentError) do
        record.discard_cycle!(discarded_at: now + 2.days, purged_at: now + 1.day)
      end

    assert_match(/discarded_at must be <= purged_at/, error.message)
    assert_equal now + 1.day, record.reload.discarded_at
  end

  test "cycle boundary predicates follow retention and expiry timestamps" do
    now = Time.zone.local(2026, 5, 19, 10, 0, 0)
    record = build_record(
      cycle_status_id: 10,
      discarded_at: now + 1.second,
      purged_at: now + 2.seconds,
      expires_at: now + 1.second,
    )

    travel_to now do
      assert_predicate record, :cycle_accessible?
      assert_not record.cycle_expired?
      assert_not record.cycle_purgeable?
    end

    travel_to now + 1.second do
      assert_not record.cycle_accessible?
      assert_predicate record, :cycle_expired?
      assert_not record.cycle_purgeable?
    end

    travel_to now + 2.seconds do
      assert_predicate record, :cycle_purgeable?
    end
  end

  private

  def build_record(**attrs)
    defaults = {
      cycle_status_id: 10,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    }
    CycleBaseTestRecord.create!(defaults.merge(attrs))
  end
end
