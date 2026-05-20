# typed: false
# frozen_string_literal: true

# rubocop:disable ThreadSafety/ClassAndModuleAttributes

module Cycle
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class InvalidTransition < Error; end

  module Base
    extend ActiveSupport::Concern

    included do
      class_attribute :cycle_status_column_name, instance_accessor: false
    end

    class_methods do
      def cycle_status_column(column_name)
        self.cycle_status_column_name = column_name.to_sym
      end
    end

    def cycle_status_id
      self[configured_cycle_status_column]
    end

    def cycle_status?(status_id)
      cycle_status_id == status_id
    end

    def cycle_accessible?(now = Time.current)
      cycle_future_time?(read_cycle_time(:discarded_at), now)
    end

    def cycle_expired?(now = Time.current)
      !cycle_accessible?(now) || cycle_expires_at_lapsed?(now)
    end

    def cycle_purgeable?(now = Time.current)
      cycle_past_or_present_time?(read_cycle_time(:purged_at), now)
    end

    def transition_cycle_to!(next_status_id, allowed_from:, changes: {}, now: Time.current)
      with_cycle_lock do
        ensure_cycle_transition_allowed!(next_status_id, allowed_from: allowed_from, now: now)

        update!(changes.merge(configured_cycle_status_column => next_status_id))
      end
    end

    def discard_cycle!(discarded_at: Time.current, purged_at:)
      with_cycle_lock do
        ensure_retention_order!(discarded_at: discarded_at, purged_at: purged_at)

        update!(discarded_at: discarded_at, purged_at: purged_at)
      end
    end

    def with_cycle_lock
      raise ArgumentError, "block required" unless block_given?
      raise InvalidTransition, "cycle must be persisted" unless persisted?

      self.class.connection_class_for_self.connected_to(role: :writing) do
        lock!
        yield
      end
    end

    private

    def configured_cycle_status_column
      column = self.class.cycle_status_column_name
      raise ConfigurationError, "#{self.class.name} must configure cycle_status_column" if column.blank?

      ensure_cycle_column!(column)
      column
    end

    def ensure_cycle_transition_allowed!(next_status_id, allowed_from:, now:)
      allowed_statuses = Array(allowed_from)
      unless allowed_statuses.include?(cycle_status_id)
        raise InvalidTransition, "invalid transition from #{cycle_status_id.inspect} to #{next_status_id.inspect}"
      end

      raise InvalidTransition, "cycle is discarded" unless cycle_accessible?(now)
      raise InvalidTransition, "cycle is expired" if cycle_expires_at_lapsed?(now)
    end

    def ensure_cycle_column!(column)
      return if has_attribute?(column)

      raise ConfigurationError, "#{self.class.name} does not have #{column}"
    end

    def read_cycle_time(column)
      ensure_cycle_column!(column)
      public_send(column)
    end

    def cycle_expires_at_lapsed?(now)
      return false unless has_attribute?(:expires_at)

      cycle_past_or_present_time?(expires_at, now)
    end

    def ensure_retention_order!(discarded_at:, purged_at:)
      raise ArgumentError, "discarded_at is required" if discarded_at.blank?
      raise ArgumentError, "purged_at is required" if purged_at.blank?
      raise ArgumentError, "discarded_at must be <= purged_at" if cycle_time_after?(discarded_at, purged_at)
    end

    def cycle_future_time?(value, now)
      return true if cycle_infinite_time?(value)

      value.present? && value > now
    end

    def cycle_past_or_present_time?(value, now)
      return false if value.blank? || cycle_infinite_time?(value)

      value <= now
    end

    def cycle_time_after?(left, right)
      return false if left.blank? || right.blank?
      return false if cycle_infinite_time?(left) && cycle_infinite_time?(right)
      return true if cycle_infinite_time?(left)
      return false if cycle_infinite_time?(right)

      left > right
    end

    def cycle_infinite_time?(value)
      value.respond_to?(:infinite?) && value.infinite?
    end
  end
end

# rubocop:enable ThreadSafety/ClassAndModuleAttributes
