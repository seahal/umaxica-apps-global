# typed: false
# frozen_string_literal: true

require "test_helper"

class RetentionShreddableTest < ActiveSupport::TestCase
  class ShreddableTestRecord < ApplicationRecord
    self.table_name = "shreddable_test_records"

    include Retention::Shreddable

    attr_accessor :callback_events

    validates :name, presence: true

    before_shred { callback_events << :before_shred }
    after_shred { callback_events << :after_shred }

    after_initialize do
      self.callback_events ||= []
    end
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:shreddable_test_records, force: true) do |t|
      t.string(:name)
      t.datetime(:purged_at, null: false, default: -> { "'infinity'" })
      t.timestamps
    end
    ShreddableTestRecord.reset_column_information
  end

  teardown do
    @connection.drop_table(:shreddable_test_records, if_exists: true)
  end

  test "default state is not shreddable" do
    record = create_record

    assert_equal Retention::Shreddable::SENTINEL, record.purged_at
    assert_not record.shreddable?
    assert_empty ShreddableTestRecord.shreddable
  end

  test "purged_at is required" do
    record = ShreddableTestRecord.new(name: "missing-purged-at", purged_at: nil)

    assert_not record.valid?
    assert_includes record.errors[:purged_at], "can't be blank"
  end

  test "shreddable scope selects rows whose purge time has arrived" do
    future = create_record(name: "future", purged_at: 1.hour.from_now)
    due = create_record(name: "due", purged_at: Time.current)
    past = create_record(name: "past", purged_at: 1.hour.ago)

    assert_equal [due.id, past.id].sort, ShreddableTestRecord.shreddable.pluck(:id).sort
    assert_not_includes ShreddableTestRecord.shreddable.pluck(:id), future.id
  end

  test "schedule and unschedule shredding update purged_at" do
    record = create_record
    scheduled_at = 1.hour.ago

    assert_same true, record.schedule_shredding_at(scheduled_at)
    assert_equal scheduled_at.to_i, record.reload.purged_at.to_i
    assert_predicate record, :shreddable?

    assert_same true, record.unschedule_shredding
    assert_equal Retention::Shreddable::SENTINEL, record.reload.purged_at
    assert_not record.shreddable?
  end

  test "bang schedule and unschedule raise on validation failure" do
    record = create_record
    record.name = nil

    assert_raises(ActiveRecord::RecordInvalid) { record.schedule_shredding_at!(Time.current) }
    assert_equal Retention::Shreddable::SENTINEL, record.reload.purged_at

    record.update!(purged_at: 1.hour.ago)
    record.name = nil

    assert_raises(ActiveRecord::RecordInvalid) { record.unschedule_shredding! }
    assert_predicate record.reload, :shreddable?
  end

  test "shred destroys only records whose purge time has arrived" do
    future = create_record(name: "future", purged_at: 1.hour.from_now)
    due = create_record(name: "due", purged_at: 1.hour.ago)

    assert_no_difference -> { ShreddableTestRecord.count } do
      assert_same false, future.shred
    end

    assert_difference -> { ShreddableTestRecord.count }, -1 do
      assert due.shred
    end
    assert_not ShreddableTestRecord.exists?(due.id)
  end

  test "shred! raises unless purge time has arrived" do
    record = create_record(purged_at: 1.hour.from_now)

    assert_raises(ActiveRecord::RecordNotDestroyed) { record.shred! }
    assert ShreddableTestRecord.exists?(record.id)
  end

  test "callbacks fire around shred" do
    record = create_record(purged_at: 1.hour.ago)

    record.shred

    assert_equal %i(before_shred after_shred), record.callback_events
  end

  test "class methods shred only due records" do
    future = create_record(name: "future", purged_at: 1.hour.from_now)
    first_due = create_record(name: "first-due", purged_at: 1.hour.ago)
    second_due = create_record(name: "second-due", purged_at: Time.current)

    result = ShreddableTestRecord.shred_all!

    assert_equal [first_due.id, second_due.id].sort, result.map(&:id).sort
    assert ShreddableTestRecord.exists?(future.id)
    assert_not ShreddableTestRecord.exists?(first_due.id)
    assert_not ShreddableTestRecord.exists?(second_due.id)
  end

  test "destroy and delete are not overridden" do
    destroy_record = create_record(purged_at: 1.hour.from_now)
    delete_record = create_record(purged_at: 1.hour.from_now)

    assert_difference -> { ShreddableTestRecord.count }, -1 do
      destroy_record.destroy
    end

    assert_difference -> { ShreddableTestRecord.count }, -1 do
      delete_record.delete
    end
  end

  test "default scope is not introduced" do
    record = create_record(purged_at: 1.hour.ago)

    assert_equal [record.id], ShreddableTestRecord.pluck(:id)
    assert_no_match(/purged_at/, ShreddableTestRecord.all.to_sql)
  end

  private

  def create_record(name: "record", purged_at: Retention::Shreddable::SENTINEL)
    ShreddableTestRecord.create!(name: name, purged_at: purged_at)
  end
end
