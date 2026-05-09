# typed: false
# frozen_string_literal: true

module TokenStatusManagement
  extend ActiveSupport::Concern

  RESTRICTED_TTL = 15.minutes

  STATUS_ACTIVE = "active"
  STATUS_RESTRICTED = "restricted"
  STATUS_REVOKED = "revoked"

  VALID_STATUSES = [STATUS_ACTIVE, STATUS_RESTRICTED, STATUS_REVOKED].freeze

  included do
    scope :session_inventory, ->(now = Time.current) { currently_usable_at(now) }
    scope :active_status, ->(now = Time.current) { currently_usable_at(now).where(status: STATUS_ACTIVE) }
    scope :restricted_status, ->(now = Time.current) { currently_usable_at(now).where(status: STATUS_RESTRICTED) }
    scope :not_revoked, ->(now = Time.current) { currently_usable_at(now) }

    validates :status, inclusion: { in: VALID_STATUSES }, length: { maximum: 20 }
    attribute :status, default: STATUS_ACTIVE
  end

  def restricted?
    status == STATUS_RESTRICTED
  end

  def active_status? = status == STATUS_ACTIVE && currently_usable?

  def mark_restricted!
    update!(status: STATUS_RESTRICTED)
  end

  def promote_to_active!
    update!(status: STATUS_ACTIVE)
  end

  def revoke!
    now = Time.current
    attrs = { status: STATUS_REVOKED }
    if has_attribute?(:lapses_at)
      attrs[:lapses_at] = [now, created_at].compact.max
    end
    update!(attrs)
  end

  def expired?
    return true if respond_to?(:lapses_at) && has_attribute?(:lapses_at) && past_or_present_time?(lapses_at)
    return true if scheduled_revocation_due?

    false
  end

  def currently_usable?(now = Time.current)
    return false if expired?
    return false if has_attribute?(:rotated_at) && rotated_at.present?
    return false if has_attribute?(:lapses_at) && past_or_present_time?(lapses_at, now)

    true
  end

  def scheduled_revocation_due?(now = Time.current)
    has_attribute?(:lapses_at) && past_or_present_time?(lapses_at, now)
  end

  module ClassMethods
    def currently_usable_at(now = Time.current)
      scope = currently_valid_at(now)
      scope = scope.where(rotated_at: nil) if column_names.include?("rotated_at")

      if column_names.include?("lapses_at")
        scope = scope.where(arel_table[:lapses_at].gt(now))
      end

      scope
    end

    def currently_valid_at(now = Time.current)
      return all unless column_names.include?("lapses_at")

      where(arel_table[:lapses_at].gt(now))
    end

    def expiry_column
      return :lapses_at if column_names.include?("lapses_at")

      raise ArgumentError, "#{name} does not have lapses_at column"
    end
  end

  private

  def past_or_present_time?(value, now = Time.current)
    return false if value.blank?
    return false if value.respond_to?(:infinite?) && value.infinite?

    value <= now
  end
end
