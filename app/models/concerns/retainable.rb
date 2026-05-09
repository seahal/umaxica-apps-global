# typed: false
# frozen_string_literal: true

module Retainable
  extend ActiveSupport::Concern

  SENTINEL = ::Float::INFINITY

  included do
    attribute :lapses_at, :datetime, default: -> { SENTINEL }
    attribute :purge_at, :datetime, default: -> { SENTINEL }

    validates :lapses_at, presence: true
    validates :purge_at, presence: true
    validate :lapses_at_not_after_purge_at
    validate :retention_times_not_before_created_at, on: :update
  end

  # NOTE: ActiveRecord scope はあえて定義しない（既存 `.active` / `.deletable` 等の
  #   暗黙挙動と混乱するため）。クエリは raw `where('lapses_at > ?', Time.current)` で書く。

  def accessible?
    future_time?(lapses_at)
  end

  def lapsed?
    !future_time?(lapses_at)
  end

  def purgeable?
    !future_time?(purge_at)
  end

  def schedule_retention!(lapses_at:, purge_at:)
    raise ArgumentError, "lapses_at must be in the future" unless future_time?(lapses_at)
    raise ArgumentError, "purge_at must be in the future" unless future_time?(purge_at)
    raise ArgumentError, "lapses_at must be <= purge_at" if time_after?(lapses_at, purge_at)

    update!(lapses_at: lapses_at, purge_at: purge_at)
  end

  private

  def lapses_at_not_after_purge_at
    return if lapses_at.blank? || purge_at.blank?

    return unless time_after?(lapses_at, purge_at)

    Rails.logger.debug { "DEBUG: #{self.class.name} lapses_at: #{lapses_at.inspect}, purge_at: #{purge_at.inspect}" }
    errors.add(:lapses_at, "must be <= purge_at")

  end

  def retention_times_not_before_created_at
    return if created_at.blank?

    errors.add(:lapses_at, "must be >= created_at") if time_before?(lapses_at, created_at)
    errors.add(:purge_at, "must be >= created_at") if time_before?(purge_at, created_at)
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
