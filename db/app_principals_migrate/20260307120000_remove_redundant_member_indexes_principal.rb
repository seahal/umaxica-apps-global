# frozen_string_literal: true

class RemoveRedundantMemberIndexesPrincipal < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  INDEXES = {
    user_member_deletions: :index_user_member_deletions_on_user_id,
    user_member_discoveries: :index_user_member_discoveries_on_user_id,
    user_member_impersonations: :index_user_member_impersonations_on_user_id,
    user_member_observations: :index_user_member_observations_on_user_id,
    user_member_revocations: :index_user_member_revocations_on_user_id,
    user_member_suspensions: :index_user_member_suspensions_on_user_id,
    user_members: :index_user_members_on_user_id,
  }.freeze

  def up
    safety_assured do
      INDEXES.each do |table, index_name|
        remove_index(table, name: index_name, algorithm: :concurrently, if_exists: true)
      end
    end
  end

  def down
    safety_assured do
      INDEXES.each do |table, index_name|
        add_index(table, :user_id, name: index_name, algorithm: :concurrently) unless index_exists?(
          table, :user_id,
          name: index_name,
        )
      end
    end
  end
end
