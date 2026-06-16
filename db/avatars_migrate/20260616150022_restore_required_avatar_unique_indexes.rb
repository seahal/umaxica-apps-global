# frozen_string_literal: true

class RestoreRequiredAvatarUniqueIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index(:avatar_assignments, :avatar_id, unique: true, where: "((role)::text = 'affiliation'::text)",
                                    name: "index_avatar_assignments_unique_affiliation", algorithm: :concurrently) unless
      index_exists?(:avatar_assignments, name: "index_avatar_assignments_unique_affiliation")
    add_index(:avatar_assignments, :avatar_id, unique: true, where: "((role)::text = 'owner'::text)",
                                    name: "index_avatar_assignments_unique_owner", algorithm: :concurrently) unless
      index_exists?(:avatar_assignments, name: "index_avatar_assignments_unique_owner")
    add_index(:avatar_monikers, :avatar_id, unique: true,
                                where: "(valid_to = 'infinity'::timestamp with time zone)",
                                name: "index_avatar_monikers_on_avatar_id", algorithm: :concurrently) unless
      index_exists?(:avatar_monikers, name: "index_avatar_monikers_on_avatar_id")
    add_index(:handle_assignments, :avatar_id, unique: true,
                                    where: "(valid_to = 'infinity'::timestamp with time zone)",
                                    name: "index_handle_assignments_on_avatar_id", algorithm: :concurrently) unless
      index_exists?(:handle_assignments, name: "index_handle_assignments_on_avatar_id")
    add_index(:handle_assignments, :handle_id, unique: true,
                                    where: "(valid_to = 'infinity'::timestamp with time zone)",
                                    name: "index_handle_assignments_on_handle_id", algorithm: :concurrently) unless
      index_exists?(:handle_assignments, name: "index_handle_assignments_on_handle_id")
  end

  def down
    remove_index(:avatar_assignments, name: "index_avatar_assignments_unique_affiliation", algorithm: :concurrently) if
      index_exists?(:avatar_assignments, name: "index_avatar_assignments_unique_affiliation")
    remove_index(:avatar_assignments, name: "index_avatar_assignments_unique_owner", algorithm: :concurrently) if
      index_exists?(:avatar_assignments, name: "index_avatar_assignments_unique_owner")
    remove_index(:avatar_monikers, name: "index_avatar_monikers_on_avatar_id", algorithm: :concurrently) if
      index_exists?(:avatar_monikers, name: "index_avatar_monikers_on_avatar_id")
    remove_index(:handle_assignments, name: "index_handle_assignments_on_avatar_id", algorithm: :concurrently) if
      index_exists?(:handle_assignments, name: "index_handle_assignments_on_avatar_id")
    remove_index(:handle_assignments, name: "index_handle_assignments_on_handle_id", algorithm: :concurrently) if
      index_exists?(:handle_assignments, name: "index_handle_assignments_on_handle_id")
  end
end
