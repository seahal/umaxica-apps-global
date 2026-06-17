# typed: false
# frozen_string_literal: true

require "test_helper"

class RetainableTest < ActiveSupport::TestCase
  class DummyRetainable
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include Retainable

    attribute :created_at, :datetime, default: -> { Time.current }

    # We need to simulate ActiveRecord update context for the validation
    def validation_context
      @validation_context || :default
    end
    attr_writer :validation_context

    # mock update! for schedule_retention!
    def update!(attrs)
      assign_attributes(attrs)
      raise ActiveRecord::RecordInvalid.new(self) unless valid?

      true
    end
  end

  setup do
    @dummy = DummyRetainable.new
  end

  test "accessible? returns true if discarded_at is in the future" do
    @dummy.discarded_at = 1.hour.from_now

    assert_predicate @dummy, :accessible?

    @dummy.discarded_at = Retainable::SENTINEL

    assert_predicate @dummy, :accessible?
  end

  test "accessible? returns false if discarded_at is in the past" do
    @dummy.discarded_at = 1.hour.ago

    assert_not @dummy.accessible?
  end

  test "lapsed? returns true if discarded_at is in the past" do
    @dummy.discarded_at = 1.hour.ago

    assert_predicate @dummy, :lapsed?
  end

  test "purgeable? returns true if purged_at is in the past" do
    @dummy.purged_at = 1.hour.ago

    assert_predicate @dummy, :purgeable?
  end

  test "defaults use infinity sentinel" do
    assert_equal Float::INFINITY, @dummy.discarded_at
    assert_equal Float::INFINITY, @dummy.purged_at
  end

  test "validates discarded_at <= purged_at" do
    @dummy.discarded_at = 2.hours.from_now
    @dummy.purged_at = 1.hour.from_now

    assert_not @dummy.valid?
    assert_includes @dummy.errors[:discarded_at], "must be <= purged_at"
  end

  test "validates retention times not before created_at on update" do
    @dummy.created_at = 2.hours.ago
    @dummy.validation_context = :update

    @dummy.discarded_at = 3.hours.ago

    assert_not @dummy.valid?
    assert_includes @dummy.errors[:discarded_at], "must be >= created_at"

    @dummy.purged_at = 3.hours.ago
    @dummy.valid?

    assert_includes @dummy.errors[:purged_at], "must be >= created_at"
  end

  test "schedule_retention! raises ArgumentError if times are invalid" do
    assert_raises(ArgumentError) { @dummy.schedule_retention!(discarded_at: 1.hour.ago, purged_at: 1.hour.from_now) }
    assert_raises(ArgumentError) { @dummy.schedule_retention!(discarded_at: 1.hour.from_now, purged_at: 1.hour.ago) }
    assert_raises(ArgumentError) {
      @dummy.schedule_retention!(discarded_at: 2.hours.from_now, purged_at: 1.hour.from_now)
    }
  end

  test "schedule_retention! updates attributes if valid" do
    future_lapses = 1.day.from_now
    future_purge = 2.days.from_now

    @dummy.schedule_retention!(discarded_at: future_lapses, purged_at: future_purge)

    assert_equal future_lapses, @dummy.discarded_at
    assert_equal future_purge, @dummy.purged_at
  end

  test "validation debug log fires when discarded_at after purged_at" do
    original_level = Rails.logger.level
    Rails.logger.level = Logger::DEBUG

    @dummy.discarded_at = 2.hours.from_now
    @dummy.purged_at = 1.hour.from_now

    assert_not @dummy.valid?
    assert_includes @dummy.errors[:discarded_at], "must be <= purged_at"
  ensure
    Rails.logger.level = original_level
  end
end
