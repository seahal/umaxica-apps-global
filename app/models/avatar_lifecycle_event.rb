# typed: false
# frozen_string_literal: true

# Audit trail for Avatar lifecycle transitions.
class AvatarLifecycleEvent < AvatarRecord
  STATE_KEYS = %w(active suspended archived banned deleted).freeze

  belongs_to :avatar

  validates :from_state_key, presence: true, inclusion: { in: STATE_KEYS }
  validates :to_state_key, presence: true, inclusion: { in: STATE_KEYS }
  validates :to_state_key, comparison: { other_than: :from_state_key }, if: -> {
    from_state_key.present? && to_state_key.present?
  }
end
