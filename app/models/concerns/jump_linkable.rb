# typed: false
# frozen_string_literal: true

module JumpLinkable
  extend ActiveSupport::Concern

  STATUS_ACTIVE = 0
  STATUS_DISABLED = 1
  STATUS_REVOKED = 2
  FAR_FUTURE = Time.utc(9999, 12, 31, 23, 59, 59)

  included do
    const_set(:STATUS_ACTIVE, JumpLinkable::STATUS_ACTIVE) unless const_defined?(:STATUS_ACTIVE, false)
    const_set(:STATUS_DISABLED, JumpLinkable::STATUS_DISABLED) unless const_defined?(:STATUS_DISABLED, false)
    const_set(:STATUS_REVOKED, JumpLinkable::STATUS_REVOKED) unless const_defined?(:STATUS_REVOKED, false)
    const_set(:FAR_FUTURE, JumpLinkable::FAR_FUTURE) unless const_defined?(:FAR_FUTURE, false)

    before_validation :generate_public_id, on: :create
    before_validation :fill_sentinel_timestamps

    validates :public_id, presence: true, uniqueness: true, length: { is: 21 }
    validates :destination_url, presence: true
    validates :status_id, :max_uses, :uses_count, presence: true
    validates :revoked_at, :deletable_at, presence: true
    validates :max_uses, :uses_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end

  def active?
    status_id == STATUS_ACTIVE
  end

  def available_for?(user:)
    active? &&
      Time.current < revoked_at &&
      (max_uses.zero? || uses_count < max_uses) &&
      allowed_by_policy?(user: user)
  end

  def consume_destination_for(user:)
    with_lock do
      return nil unless available_for?(user: user)

      update!(uses_count: uses_count + 1)
      destination_url
    end
  end

  def revoke!
    update!(status_id: STATUS_REVOKED, revoked_at: Time.current)
  end

  private

  def generate_public_id
    self.public_id = Nanoid.generate(size: 21) if public_id.blank?
  end

  def fill_sentinel_timestamps
    self.revoked_at ||= FAR_FUTURE
    self.deletable_at ||= FAR_FUTURE
  end

  def allowed_by_policy?(*)
    true
  end
end
