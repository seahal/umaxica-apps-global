# typed: false
# frozen_string_literal: true

class DirectMessageThread < MessageRecord
  include PublicId

  validates :initiator_actor_id, presence: true
  validates :recipient_actor_id, presence: true
  validate :participants_are_distinct

  private

  def participants_are_distinct
    return if initiator_actor_id.blank? || recipient_actor_id.blank?
    return unless initiator_actor_id == recipient_actor_id

    errors.add(:recipient_actor_id, :invalid)
  end
end
