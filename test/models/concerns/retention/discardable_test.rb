# typed: false
# frozen_string_literal: true

require "test_helper"

class RetentionDiscardableTest < ActiveSupport::TestCase
  class DiscardableTestRecord < ApplicationRecord
    self.table_name = "discardable_test_records"

    include Retention::Discardable

    attr_accessor :callback_events

    validates :name, presence: true

    before_discard { callback_events << :before_discard }
    after_discard { callback_events << :after_discard }
    before_undiscard { callback_events << :before_undiscard }
    after_undiscard { callback_events << :after_undiscard }

    after_initialize do
      self.callback_events ||= []
    end
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:discardable_test_records, force: true) do |t|
      t.string(:name)
      t.datetime(:discarded_at, null: false, default: -> { "'infinity'" })
      t.timestamps
    end
    DiscardableTestRecord.reset_column_information
  end

  teardown do
    @connection.drop_table(:discardable_test_records, if_exists: true)
  end

  test "default state is kept" do
    record = create_record

    assert_equal Retention::Discardable::SENTINEL, record.discarded_at
    assert_predicate record, :kept?
    assert_predicate record, :undiscarded?
    assert_not record.discarded?
  end

  test "kept discarded and with_discarded scopes filter explicitly" do
    kept_record = create_record(name: "kept")
    discarded_record = create_record(name: "discarded")
    discarded_record.discard!

    assert_equal [kept_record.id], DiscardableTestRecord.kept.pluck(:id)
    assert_equal [discarded_record.id], DiscardableTestRecord.discarded.pluck(:id)
    assert_equal [kept_record.id, discarded_record.id].sort, DiscardableTestRecord.with_discarded.pluck(:id).sort
  end

  test "kept relation carries the state predicate through lazy evaluation" do
    record = create_record
    record.discard!

    assert_raises(ActiveRecord::RecordNotFound) { DiscardableTestRecord.kept.find(record.id) }
    assert_equal record, DiscardableTestRecord.discarded.find(record.id)
    assert_equal record, DiscardableTestRecord.with_discarded.find(record.id)
  end

  test "plain rails find and where are not changed" do
    record = create_record
    record.discard!

    assert_equal record, DiscardableTestRecord.find(record.id)
    assert_equal [record.id], DiscardableTestRecord.where(id: record.id).pluck(:id)
  end

  test "predicates follow discarded_at time axis" do
    record = create_record

    assert_predicate record, :kept?
    assert_predicate record, :undiscarded?
    assert_not record.discarded?

    record.discard!

    assert_predicate record, :discarded?
    assert_not record.kept?
    assert_not record.undiscarded?
  end

  test "discard updates the state and returns true" do
    record = create_record

    assert_same true, record.discard
    assert_predicate record.reload, :discarded?
    assert_operator record.discarded_at, :<=, Time.current
  end

  test "discard returns false when update validations fail" do
    record = create_record
    record.name = nil

    assert_same false, record.discard
    assert_predicate record.reload, :kept?
  end

  test "discard! updates the state or raises when validations fail" do
    record = create_record

    assert_same true, record.discard!
    assert_predicate record.reload, :discarded?

    invalid_record = create_record(name: "invalid")
    invalid_record.name = nil

    assert_raises(ActiveRecord::RecordInvalid) { invalid_record.discard! }
    assert_predicate invalid_record.reload, :kept?
  end

  test "undiscard updates the state and returns true" do
    record = create_record
    record.discard!

    assert_same true, record.undiscard
    assert_equal Retention::Discardable::SENTINEL, record.reload.discarded_at
  end

  test "undiscard returns false when update validations fail" do
    record = create_record
    record.discard!
    record.name = nil

    assert_same false, record.undiscard
    assert_predicate record.reload, :discarded?
  end

  test "undiscard! updates the state or raises when validations fail" do
    record = create_record
    record.discard!

    assert_same true, record.undiscard!
    assert_predicate record.reload, :kept?

    invalid_record = create_record(name: "invalid")
    invalid_record.discard!
    invalid_record.name = nil

    assert_raises(ActiveRecord::RecordInvalid) { invalid_record.undiscard! }
    assert_predicate invalid_record.reload, :discarded?
  end

  test "discard and undiscard are idempotent in target state" do
    record = create_record
    record.discard!
    record.callback_events.clear

    assert_same true, record.discard
    assert_same true, record.discard!
    assert_empty record.callback_events
    assert_predicate record.reload, :discarded?

    record.undiscard!
    record.callback_events.clear

    assert_same true, record.undiscard
    assert_same true, record.undiscard!
    assert_empty record.callback_events
    assert_predicate record.reload, :kept?
  end

  test "callbacks fire around discard and undiscard transitions" do
    record = create_record

    record.discard!

    assert_equal %i(before_discard after_discard), record.callback_events

    record.callback_events.clear
    record.undiscard!

    assert_equal %i(before_undiscard after_undiscard), record.callback_events
  end

  test "callback abort prevents non bang transition and bang transition raises" do
    aborting_class =
      Class.new(DiscardableTestRecord) do
        self.table_name = "discardable_test_records"
        before_discard { throw(:abort) }
      end

    record = aborting_class.create!(name: "abort")

    assert_same false, record.discard
    assert_predicate record.reload, :kept?
    assert_raises(ActiveRecord::RecordNotSaved) { record.discard! }
    assert_predicate record.reload, :kept?
  end

  test "class methods transition matching records through callbacks" do
    first = create_record(name: "first")
    second = create_record(name: "second")

    result = DiscardableTestRecord.discard_all!

    assert_equal [first.id, second.id].sort, result.map(&:id).sort
    assert DiscardableTestRecord.where(id: [first.id, second.id]).all?(&:discarded?)

    result = DiscardableTestRecord.undiscard_all

    assert_equal [first.id, second.id].sort, result.map(&:id).sort
    assert DiscardableTestRecord.where(id: [first.id, second.id]).all?(&:kept?)
  end

  test "destroy and delete behavior is not overridden" do
    destroy_record = create_record(name: "destroy")
    delete_record = create_record(name: "delete")

    assert_difference -> { DiscardableTestRecord.count }, -1 do
      destroy_record.destroy
    end
    assert_not DiscardableTestRecord.exists?(destroy_record.id)

    assert_difference -> { DiscardableTestRecord.count }, -1 do
      delete_record.delete
    end
    assert_not DiscardableTestRecord.exists?(delete_record.id)
  end

  test "default scope is not introduced" do
    discarded_record = create_record
    discarded_record.discard!

    assert_equal [discarded_record.id], DiscardableTestRecord.pluck(:id)
    assert_no_match(/discarded_at/, DiscardableTestRecord.all.to_sql)
  end

  test "deleted_at and retention_state_id soft delete columns are not used" do
    columns = DiscardableTestRecord.column_names

    assert_includes columns, "discarded_at"
    assert_not DiscardableTestRecord.columns_hash.fetch("discarded_at").null
    assert_not_includes columns, "retention_state_id"
    assert_not_includes columns, "deleted_at"
  end

  private

  def create_record(name: "record")
    DiscardableTestRecord.create!(name: name)
  end
end
