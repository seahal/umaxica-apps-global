# typed: false
# frozen_string_literal: true

class Actor
  module LifecycleConsistency
    extend ActiveSupport::Concern

    included do
      validate :lifecycle_timestamps_are_consistent
      validate :multi_factor_requirement_columns_are_consistent
    end

    private

    def lifecycle_timestamps_are_consistent
      validate_withdrawal_order
      validate_termination_is_after_withdrawal
    end

    def validate_withdrawal_order
      return unless has_attribute?(:withdrawal_started_at) && has_attribute?(:withdrawn_at)
      return if withdrawal_started_at.blank? || lifecycle_infinite_time?(withdrawn_at)
      return if withdrawn_at.blank? || withdrawal_started_at <= withdrawn_at

      errors.add(:withdrawn_at, "must be after withdrawal_started_at")
    end

    def validate_termination_is_after_withdrawal
      return unless has_attribute?(:terminated_at)
      return if terminated_at.blank?

      return if has_attribute?(:withdrawn_at) && withdrawn_at.present? && !lifecycle_infinite_time?(withdrawn_at)

      errors.add(:terminated_at, "requires a finite withdrawn_at")

    end

    def multi_factor_requirement_columns_are_consistent
      return unless has_attribute?(:multi_factor_enabled) && has_attribute?(:multi_factor_id)

      enabled = ActiveModel::Type::Boolean.new.cast(self[:multi_factor_enabled])
      if enabled && multi_factor_id.to_i == multi_factor_nothing_id
        errors.add(:multi_factor_id, "must not be nothing when multi_factor_enabled is true")
      elsif !enabled && multi_factor_id.to_i != multi_factor_nothing_id
        errors.add(:multi_factor_enabled, "must be true when multi_factor_id requires multi-factor")
      end
    end

    def lifecycle_infinite_time?(value)
      value.respond_to?(:infinite?) && value.infinite?
    end
  end
end
