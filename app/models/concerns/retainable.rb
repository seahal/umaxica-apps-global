# typed: false
# frozen_string_literal: true

module Retainable
  extend ActiveSupport::Concern

  SENTINEL = ::Float::INFINITY

  # Models that include Retainable register themselves here. Used by the
  # `RetentionPurgeJob` allowlist test to assert that any new retainable
  # model is actually picked up by the worker -- forgetting to add a new
  # model leaves rows purgeable in principle but never purged in practice.
  REGISTRY = Concurrent::Array.new
  private_constant :REGISTRY

  class << self
    def registry
      REGISTRY
    end
  end

  included do
    attribute :discarded_at, :datetime, default: -> { SENTINEL }
    attribute :purged_at, :datetime, default: -> { SENTINEL }

    validates :discarded_at, presence: true
    validates :purged_at, presence: true
    validate :discarded_at_not_after_purged_at
    validate :retention_times_not_before_created_at, on: :update

    Retainable.registry << self unless Retainable.registry.include?(self)
  end

  # NOTE: ActiveRecord scope intentionally omitted (conflicts with pre-existing
  #   `.active` / `.deletable` semantics). Use raw `where('discarded_at > ?', Time.current)` for queries.

  def accessible?
    future_time?(discarded_at)
  end

  def lapsed?
    !future_time?(discarded_at)
  end

  def purgeable?
    !future_time?(purged_at)
  end

  # Schedule a future logical+physical deletion window. Both timestamps must be
  # in the future. Use this when scheduling retention up front (e.g. issuing a
  # token with a known expiry).
  def schedule_retention!(discarded_at:, purged_at:)
    raise ArgumentError, "discarded_at must be in the future" unless future_time?(discarded_at)
    raise ArgumentError, "purged_at must be in the future" unless future_time?(purged_at)
    raise ArgumentError, "discarded_at must be <= purged_at" if time_after?(discarded_at, purged_at)

    update!(discarded_at: discarded_at, purged_at: purged_at)
  end

  # Mark as logically deleted *now* and schedule physical deletion after
  # `purge_after`. Use this for cancellation / expiration / failure paths where
  # the row stops being visible immediately and is eligible for purge later.
  #
  # `discarded_at` clamps to `created_at` to satisfy the
  # `retention_times_not_before_created_at` invariant when the row was created
  # in the same request (Time.current may be less than created_at by us).
  def discard_now!(purge_after:, now: Time.current)
    raise ArgumentError, "purge_after must be a Duration" unless purge_after.respond_to?(:from_now)

    discarded_at_value = persisted_created_at_or(now)
    purged_at_value = now + purge_after
    raise ArgumentError, "purged_at must be in the future" unless future_time?(purged_at_value)
    raise ArgumentError, "discarded_at must be <= purged_at" if time_after?(discarded_at_value, purged_at_value)

    update!(discarded_at: discarded_at_value, purged_at: purged_at_value)
  end

  private

  def persisted_created_at_or(now)
    return now if created_at.blank?

    [created_at, now].max
  end

  def discarded_at_not_after_purged_at
    return if discarded_at.blank? || purged_at.blank?

    return unless time_after?(discarded_at, purged_at)

    errors.add(:discarded_at, "must be <= purged_at")
  end

  def retention_times_not_before_created_at
    return if created_at.blank?

    errors.add(:discarded_at, "must be >= created_at") if time_before?(discarded_at, created_at)
    errors.add(:purged_at, "must be >= created_at") if time_before?(purged_at, created_at)
  end

  def future_time?(value)
    return true if value.respond_to?(:infinite?) && value.infinite?

    value.present? && value > Time.current
  end

  def time_after?(left, right)
    return false if left.blank? || right.blank?
    return false if left.respond_to?(:infinite?) && left.infinite? && right.respond_to?(:infinite?) && right.infinite?
    return true if left.respond_to?(:infinite?) && left.infinite?
    return false if right.respond_to?(:infinite?) && right.infinite?

    left > right
  end

  def time_before?(left, right)
    return false if left.blank? || right.blank?
    return false if left.respond_to?(:infinite?) && left.infinite?
    return true if right.respond_to?(:infinite?) && right.infinite?

    left < right
  end
end
