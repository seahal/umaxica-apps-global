# typed: false
# frozen_string_literal: true

# Shared withdraw/recovery logic for accounts (User, Operator, Visitor)
module Withdrawable
  extend ActiveSupport::Concern

  # Deterministic recovery window: use 31 days to match product requirement.
  WITHDRAWAL_RECOVERY_PERIOD = 31.days

  included do
    scope :withdrawn, -> { where.not(withdrawn_at: nil) }
  end

  def withdrawn?
    withdrawn_at.present? && withdrawn_at < Float::INFINITY
  end

  def active?
    !withdrawn? && !deactivated?
  end

  def deactivated?
    respond_to?(:deactivated_at) && deactivated_at.present?
  end

  def recovery_deadline
    return nil if withdrawn_at.blank? || withdrawn_at == Float::INFINITY

    withdrawn_at + WITHDRAWAL_RECOVERY_PERIOD
  end

  def can_recover?
    withdrawn? && Time.current < recovery_deadline
  end

  def permanently_deletable?
    withdrawn? && Time.current >= recovery_deadline
  end
end
