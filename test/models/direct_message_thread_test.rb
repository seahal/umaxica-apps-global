# typed: false
# frozen_string_literal: true

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
