# frozen_string_literal: true

class CreateDirectMessageThreads < ActiveRecord::Migration[8.2]
  def change
    create_table(:direct_message_threads) do |t|
      t.string(:public_id, null: false)
      t.bigint(:initiator_actor_id, null: false)
      t.bigint(:recipient_actor_id, null: false)
      t.datetime(:closed_at)
      t.timestamps
    end

    add_index(:direct_message_threads, :public_id, unique: true)
    add_index(
      :direct_message_threads,
      [:initiator_actor_id, :recipient_actor_id],
      name: "index_direct_message_threads_on_participants",
    )
    add_check_constraint(
      :direct_message_threads,
      "initiator_actor_id <> recipient_actor_id",
      name: "chk_direct_message_threads_distinct_participants",
    )
  end
end
