# typed: false
# frozen_string_literal: true

module Retainable
  extend ActiveSupport::Concern

  SENTINEL = ::Float::INFINITY

  included do
    attribute :discarded_at, :datetime, default: -> { SENTINEL }
    attribute :purged_at, :datetime, default: -> { SENTINEL }

    validates :discarded_at, presence: true
    validates :purged_at, presence: true
    validate :discarded_at_not_after_purged_at
    validate :retention_times_not_before_created_at, on: :update
  end

  # NOTE: ActiveRecord scope はあえて定義しない（既存 `.active` / `.deletable` 等の
  #   暗黙挙動と混乱するため）。クエリは raw `where('discarded_at > ?', Time.current)` で書く。

  def accessible?
    future_time?(discarded_at)
  end

  def lapsed?
    !future_time?(discarded_at)
  end

  def purgeable?
    !future_time?(purged_at)
  end

  def schedule_retention!(discarded_at:, purged_at:)
    raise ArgumentError, "discarded_at must be in the future" unless future_time?(discarded_at)
    raise ArgumentError, "purged_at must be in the future" unless future_time?(purged_at)
    raise ArgumentError, "discarded_at must be <= purged_at" if time_after?(discarded_at, purged_at)

    update!(discarded_at: discarded_at, purged_at: purged_at)
  end

  private

  def discarded_at_not_after_purged_at
    return if discarded_at.blank? || purged_at.blank?

    return unless time_after?(discarded_at, purged_at)

    Rails.logger.debug {
      "DEBUG: #{self.class.name} discarded_at: #{discarded_at.inspect}, purged_at: #{purged_at.inspect}"
    }
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
