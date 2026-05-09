# frozen_string_literal: true

class FixConsistencyAvatars < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      tables = %w(
        posts post_versions post_reviews
        avatars avatar_capabilities avatar_role_permissions avatar_roles avatar_permissions
        avatar_memberships avatar_membership_statuses avatar_monikers avatar_moniker_statuses
        avatar_ownership_periods avatar_ownership_statuses
        handles handle_statuses handle_assignments handle_assignment_statuses
      )
      existing = tables.select { |t| table_exists?(t) }
      execute("TRUNCATE TABLE #{existing.join(", ")} CASCADE") if existing.any?

      # --- Post ---
      change_column(:posts, :post_status_id, :bigint)
      unless foreign_key_exists?(:posts, :post_statuses)
        add_foreign_key(:posts, :post_statuses, column: :post_status_id)
      end

      if foreign_key_exists?(:post_versions, :posts)
        remove_foreign_key(:post_versions, :posts)
      end
      add_foreign_key(:post_versions, :posts, on_delete: :cascade)

      # --- PostReview ---
      change_column(:post_reviews, :post_review_status_id, :bigint)
      unless foreign_key_exists?(:post_reviews, :post_review_statuses)
        add_foreign_key(:post_reviews, :post_review_statuses, column: :post_review_status_id)
      end

      # --- Avatar Membership ---
      change_column(:avatar_memberships, :role_id, :bigint)
      add_index(:avatar_memberships, :role_id) unless index_exists?(:avatar_memberships, :role_id)
      # Assuming link to avatar_roles
      unless foreign_key_exists?(:avatar_memberships, :avatar_roles)
        add_foreign_key(:avatar_memberships, :avatar_roles, column: :role_id)
      end

      change_column(:avatar_memberships, :avatar_membership_status_id, :bigint)
      unless foreign_key_exists?(:avatar_memberships, :avatar_membership_statuses)
        add_foreign_key(:avatar_memberships, :avatar_membership_statuses)
      end

      # --- Avatar Role Permission ---
      change_column(:avatar_role_permissions, :avatar_role_id, :bigint)
      change_column(:avatar_role_permissions, :avatar_permission_id, :bigint)
      unless foreign_key_exists?(:avatar_role_permissions, :avatar_roles)
        add_foreign_key(:avatar_role_permissions, :avatar_roles)
      end
      unless foreign_key_exists?(:avatar_role_permissions, :avatar_permissions)
        add_foreign_key(:avatar_role_permissions, :avatar_permissions)
      end

      # --- Avatar ---
      change_column(:avatars, :capability_id, :bigint)
      unless foreign_key_exists?(:avatars, :avatar_capabilities)
        add_foreign_key(:avatars, :avatar_capabilities, column: :capability_id)
      end

      # --- Avatar Moniker ---
      change_column(:avatar_monikers, :avatar_moniker_status_id, :bigint)
      unless foreign_key_exists?(:avatar_monikers, :avatar_moniker_statuses)
        add_foreign_key(:avatar_monikers, :avatar_moniker_statuses)
      end

      # --- Avatar Ownership ---
      change_column(:avatar_ownership_periods, :avatar_ownership_status_id, :bigint)
      unless foreign_key_exists?(:avatar_ownership_periods, :avatar_ownership_statuses)
        add_foreign_key(:avatar_ownership_periods, :avatar_ownership_statuses)
      end

      # --- Handle ---
      change_column(:handles, :handle_status_id, :bigint)
      unless foreign_key_exists?(:handles, :handle_statuses)
        add_foreign_key(:handles, :handle_statuses)
      end

      # --- Handle Assignment ---
      change_column(:handle_assignments, :handle_assignment_status_id, :bigint)
      unless foreign_key_exists?(:handle_assignments, :handle_assignment_statuses)
        add_foreign_key(:handle_assignments, :handle_assignment_statuses)
      end
    end
  end

  def down; raise ActiveRecord::IrreversibleMigration; end
end
