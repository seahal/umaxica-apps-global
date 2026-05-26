# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: direct_message_threads
# Database name: message
#
#  id                 :bigint           not null, primary key
#  closed_at          :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  initiator_actor_id :bigint           not null
#  public_id          :string           not null
#  recipient_actor_id :bigint           not null
#
# Indexes
#
#  index_direct_message_threads_on_participants  (initiator_actor_id,recipient_actor_id)
#  index_direct_message_threads_on_public_id     (public_id) UNIQUE
#
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
