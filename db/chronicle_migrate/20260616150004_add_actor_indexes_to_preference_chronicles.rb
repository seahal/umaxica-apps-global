# frozen_string_literal: true

class AddActorIndexesToPreferenceChronicles < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_index :com_preference_chronicles, %i[actor_type actor_id], algorithm: :concurrently
    add_index :org_preference_chronicles, %i[actor_type actor_id], algorithm: :concurrently
  end
end
