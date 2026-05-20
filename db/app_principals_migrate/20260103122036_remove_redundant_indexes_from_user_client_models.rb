# frozen_string_literal: true

class RemoveRedundantIndexesFromUserClientModels < ActiveRecord::Migration[8.2]
  def change
    # Remove redundant user_id indexes from UserClient* tables
    # These are redundant because user_id_and_client_id composite indexes cover them
    remove_index(:user_client_suspensions, :user_id, if_exists: true)
    remove_index(:user_client_revocations, :user_id, if_exists: true)
    remove_index(:user_client_observations, :user_id, if_exists: true)
    remove_index(:user_client_impersonations, :user_id, if_exists: true)
    remove_index(:user_client_discoveries, :user_id, if_exists: true)
    remove_index(:user_client_deletions, :user_id, if_exists: true)

    # Remove redundant client_id indexes from ClientAvatar* tables
    # These are redundant because client_id_and_avatar_id composite indexes cover them
    remove_index(:client_avatar_visibilities, :client_id, if_exists: true)
    remove_index(:client_avatar_suspensions, :client_id, if_exists: true)
    remove_index(:client_avatar_oversights, :client_id, if_exists: true)
    remove_index(:client_avatar_impersonations, :client_id, if_exists: true)
    remove_index(:client_avatar_extractions, :client_id, if_exists: true)
    remove_index(:client_avatar_deletions, :client_id, if_exists: true)
    remove_index(:client_avatar_accesses, :client_id, if_exists: true)
  end
end
