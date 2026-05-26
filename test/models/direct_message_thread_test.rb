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
require "test_helper"

class DirectMessageThreadTest < ActiveSupport::TestCase
  test "creates a direct message thread in the message database" do
    thread = DirectMessageThread.create!(initiator_actor_id: 101, recipient_actor_id: 202)

    assert_predicate thread, :persisted?
    assert_not_empty thread.public_id
    assert_equal "message", DirectMessageThread.connection_db_config.name
  end

  test "is invalid without participant actor ids" do
    thread = DirectMessageThread.new

    assert_not thread.valid?
    assert_not_empty thread.errors[:initiator_actor_id]
    assert_not_empty thread.errors[:recipient_actor_id]
  end

  test "is invalid when participants are the same actor" do
    thread = DirectMessageThread.new(initiator_actor_id: 101, recipient_actor_id: 101)

    assert_not thread.valid?
    assert_not_empty thread.errors[:recipient_actor_id]
  end
end
