# frozen_string_literal: true

class ConvertAvatarUuidPksToBigint < ActiveRecord::Migration[8.2]
  def up
    # Drop referencing tables first
    drop_table(:avatar_assignments, if_exists: true)
    drop_table(:avatar_blocks, if_exists: true)
    drop_table(:avatar_follows, if_exists: true)
    drop_table(:avatar_mutes, if_exists: true)
    drop_table(:client_avatar_accesses, if_exists: true)
    drop_table(:client_avatar_deletions, if_exists: true)
    drop_table(:client_avatar_extractions, if_exists: true)
    drop_table(:client_avatar_impersonations, if_exists: true)
    drop_table(:client_avatar_oversights, if_exists: true)
    drop_table(:client_avatar_suspensions, if_exists: true)
    drop_table(:client_avatar_visibilities, if_exists: true)

    drop_table(:post_reviews, if_exists: true)
    drop_table(:post_versions, if_exists: true)
    drop_table(:posts, if_exists: true)

    drop_table(:handle_assignments, if_exists: true)
    drop_table(:avatar_memberships, if_exists: true)
    drop_table(:avatar_monikers, if_exists: true)
    drop_table(:avatar_ownership_periods, if_exists: true)

    # Drop core tables
    # Note: Avatars references Handles. Handles references HandleStatuses.
    drop_table(:avatars, if_exists: true)
    drop_table(:handles, if_exists: true)

    drop_table(:avatar_role_permissions, if_exists: true)

    # Drop status tables to convert from string to bigint
    drop_table(:handle_statuses, if_exists: true, force: :cascade)
    drop_table(:handle_assignment_statuses, if_exists: true, force: :cascade)
    drop_table(:post_statuses, if_exists: true, force: :cascade)
    drop_table(:post_review_statuses, if_exists: true, force: :cascade)
    drop_table(:avatar_roles, if_exists: true, force: :cascade)
    drop_table(:avatar_permissions, if_exists: true, force: :cascade)
    drop_table(:avatar_capabilities, if_exists: true, force: :cascade)
    drop_table(:avatar_ownership_statuses, if_exists: true, force: :cascade)
    drop_table(:avatar_moniker_statuses, if_exists: true, force: :cascade)
    drop_table(:avatar_membership_statuses, if_exists: true, force: :cascade)

    # Recreate status tables with Bigint PKs
    create_table(:handle_statuses, id: :bigint) do |t|
      t.string(:code, null: false)
      t.index(:code, unique: true)
    end

    create_table(:handle_assignment_statuses, id: :bigint) do |t|
      t.string(:code, null: false)
      t.index(:code, unique: true)
    end

    create_table(:post_statuses, id: :bigint) do |t|
      t.string(:code, null: false)
      t.index(:code, unique: true)
    end

    create_table(:post_review_statuses, id: :bigint) do |t|
      t.string(:code, null: false)
      t.index(:code, unique: true)
    end

    create_table(:avatar_roles, id: :bigint) do |t|
      t.string(:code, null: false)
      t.index(:code, unique: true)
    end

    create_table(:avatar_permissions, id: :bigint) do |t|
      t.string(:code, null: false)
      t.index(:code, unique: true)
    end

    create_table(:avatar_capabilities, id: :bigint) do |t|
      t.string(:code, null: false)
      t.index(:code, unique: true)
    end

    create_table(:avatar_ownership_statuses, id: :bigint) do |t|
      t.string(:code, null: false)
      t.index(:code, unique: true)
    end

    create_table(:avatar_moniker_statuses, id: :bigint) do |t|
      t.string(:code, null: false)
      t.index(:code, unique: true)
    end

    create_table(:avatar_membership_statuses, id: :bigint) do |t|
      t.string(:code, null: false)
      t.index(:code, unique: true)
    end

    # Recreate tables with Bigint PKs

    create_table(:handles) do |t| # implicit id: :bigint
      t.timestamptz(:cooldown_until, null: false)
      t.datetime(:created_at, null: false)
      t.string(:handle, null: false)
      t.integer(:handle_status_id, limit: 2)
      t.boolean(:is_system, default: false, null: false)
      t.string(:public_id, null: false)
      t.datetime(:updated_at, null: false)

      t.index(:cooldown_until, name: "index_handles_on_cooldown_until")
      t.index(:handle, name: "uniq_handles_handle_non_system", unique: true, where: "(is_system = false)")
      t.index(:handle_status_id, name: "index_handles_on_handle_status_id")
      t.index(:is_system, name: "index_handles_on_is_system")
      t.index(:public_id, name: "index_handles_on_public_id", unique: true)
      t.check_constraint(
        "handle_status_id IS NULL OR handle_status_id >= 0",
        name: "chk_handles_handle_status_id_positive",
      )
    end

    create_table(:avatars) do |t| # implicit id: :bigint
      t.bigint(:active_handle_id, null: false) # FK to handles
      t.string(:avatar_status_id)
      t.integer(:capability_id, limit: 2, default: 0, null: false)
      t.bigint(:client_id) # External UUID
      t.datetime(:created_at, null: false)
      t.jsonb(:image_data, default: {}, null: false)
      t.integer(:lock_version, default: 0, null: false)
      t.string(:moniker, null: false)
      t.string(:owner_organization_id) # External ID
      t.string(:public_id, null: false)
      t.string(:representing_organization_id) # External ID
      t.datetime(:updated_at, null: false)

      t.index(:active_handle_id, name: "index_avatars_on_active_handle_id")
      t.index(:capability_id, name: "index_avatars_on_capability_id")
      t.index(:client_id, name: "index_avatars_on_client_id")
      t.index(:owner_organization_id, name: "index_avatars_on_owner_organization_id")
      t.index(:public_id, name: "index_avatars_on_public_id", unique: true)
      t.index(:representing_organization_id, name: "index_avatars_on_representing_organization_id")
      t.check_constraint("capability_id >= 0", name: "chk_avatars_capability_id_positive")
    end

    create_table(:avatar_monikers) do |t| # implicit id: :bigint
      t.bigint(:avatar_id, null: false) # FK
      t.integer(:avatar_moniker_status_id, limit: 2)
      t.datetime(:created_at, null: false)
      t.string(:moniker, null: false)
      t.bigint(:set_by_actor_id)
      t.datetime(:updated_at, null: false)
      t.timestamptz(:valid_from, null: false)
      t.timestamptz(:valid_to, default: ::Float::INFINITY, null: false)

      t.index(
        [:avatar_id, :valid_from], name: "index_avatar_monikers_on_avatar_id_and_valid_from",
                                   order: { valid_from: :desc },
      )
      t.index(
        :avatar_id, name: "index_avatar_monikers_on_avatar_id", unique: true,
                    where: "(valid_to = 'infinity'::timestamp with time zone)",
      )
      t.index(:avatar_moniker_status_id, name: "index_avatar_monikers_on_avatar_moniker_status_id")
      t.check_constraint(
        "avatar_moniker_status_id IS NULL OR avatar_moniker_status_id >= 0",
        name: "chk_avatar_monikers_avatar_moniker_status_id_positive",
      )
    end

    create_table(:avatar_memberships) do |t| # implicit id: :bigint
      t.bigint(:actor_id, null: false) # String/UUID
      t.bigint(:avatar_id, null: false) # FK
      t.integer(:avatar_membership_status_id, limit: 2)
      t.datetime(:created_at, null: false)
      t.bigint(:granted_by_actor_id)
      t.integer(:role_id, limit: 2, default: 0, null: false)
      t.datetime(:updated_at, null: false)
      t.timestamptz(:valid_from, null: false)
      t.timestamptz(:valid_to, default: ::Float::INFINITY, null: false)

      t.index(
        :actor_id, name: "index_avatar_memberships_on_actor_id",
                   where: "(valid_to = 'infinity'::timestamp with time zone)",
      )
      t.index(
        [:avatar_id, :actor_id], name: "index_avatar_memberships_on_avatar_id_and_actor_id", unique: true,
                                 where: "(valid_to = 'infinity'::timestamp with time zone)",
      )
      t.index(:avatar_membership_status_id, name: "index_avatar_memberships_on_avatar_membership_status_id")
      t.check_constraint(
        "avatar_membership_status_id IS NULL OR avatar_membership_status_id >= 0",
        name: "chk_avatar_memberships_avatar_membership_status_id_positive",
      )
      t.check_constraint("role_id >= 0", name: "chk_avatar_memberships_role_id_positive")
    end

    create_table(:avatar_ownership_periods) do |t| # implicit id: :bigint
      t.bigint(:avatar_id, null: false) # FK
      t.integer(:avatar_ownership_status_id, limit: 2)
      t.datetime(:created_at, null: false)
      t.string(:owner_organization_id, null: false) # External
      t.bigint(:transferred_by_actor_id)
      t.datetime(:updated_at, null: false)
      t.timestamptz(:valid_from, null: false)
      t.timestamptz(:valid_to, default: ::Float::INFINITY, null: false)

      t.index(
        :avatar_id, name: "index_avatar_ownership_periods_on_avatar_id", unique: true,
                    where: "(valid_to = 'infinity'::timestamp with time zone)",
      )
      t.index(:avatar_ownership_status_id, name: "index_avatar_ownership_periods_on_avatar_ownership_status_id")
      t.index(
        :owner_organization_id, name: "index_avatar_ownership_periods_on_owner_organization_id",
                                where: "(valid_to = 'infinity'::timestamp with time zone)",
      )
      t.check_constraint(
        "avatar_ownership_status_id IS NULL OR avatar_ownership_status_id >= 0",
        name: "chk_avatar_ownership_periods_avatar_ownership_status_id_positiv",
      )
    end

    create_table(:handle_assignments) do |t| # implicit id: :bigint
      t.bigint(:assigned_by_actor_id)
      t.bigint(:avatar_id, null: false) # FK
      t.datetime(:created_at, null: false)
      t.integer(:handle_assignment_status_id, limit: 2)
      t.bigint(:handle_id, null: false) # FK
      t.datetime(:updated_at, null: false)
      t.timestamptz(:valid_from, null: false)
      t.timestamptz(:valid_to, default: ::Float::INFINITY, null: false)

      t.index(
        [:avatar_id, :valid_from], name: "index_handle_assignments_on_avatar_id_and_valid_from",
                                   order: { valid_from: :desc },
      )
      t.index(
        :avatar_id, name: "index_handle_assignments_on_avatar_id", unique: true,
                    where: "(valid_to = 'infinity'::timestamp with time zone)",
      )
      t.index(:handle_assignment_status_id, name: "index_handle_assignments_on_handle_assignment_status_id")
      t.index(
        [:handle_id, :valid_from], name: "index_handle_assignments_on_handle_id_and_valid_from",
                                   order: { valid_from: :desc },
      )
      t.index(
        :handle_id, name: "index_handle_assignments_on_handle_id", unique: true,
                    where: "(valid_to = 'infinity'::timestamp with time zone)",
      )
      t.check_constraint(
        "handle_assignment_status_id IS NULL OR handle_assignment_status_id >= 0",
        name: "chk_handle_assignments_handle_assignment_status_id_positive",
      )
    end

    create_table(:posts) do |t| # implicit id: :bigint
      t.bigint(:author_avatar_id, null: false) # FK
      t.text(:body, null: false)
      t.datetime(:created_at, null: false)
      t.bigint(:created_by_actor_id, null: false)
      t.integer(:post_status_id, limit: 2, default: 0, null: false)
      t.string(:public_id, null: false)
      t.timestamptz(:published_at)
      t.bigint(:published_by_actor_id)
      t.datetime(:updated_at, null: false)

      t.index(
        [:author_avatar_id, :created_at], name: "index_posts_on_author_avatar_id_and_created_at",
                                          order: { created_at: :desc },
      )
      t.index(:post_status_id, name: "index_posts_on_post_status_id")
      t.index(:public_id, name: "index_posts_on_public_id", unique: true)
      t.check_constraint("post_status_id IS NULL OR post_status_id >= 0", name: "chk_posts_post_status_id_positive")
    end

    create_table(:post_reviews) do |t| # implicit id: :bigint
      t.text(:comment)
      t.datetime(:created_at, null: false)
      t.timestamptz(:decided_at)
      t.bigint(:post_id, null: false) # FK
      t.integer(:post_review_status_id, limit: 2, default: 0, null: false)
      t.bigint(:reviewer_actor_id, null: false)
      t.datetime(:updated_at, null: false)

      t.index([:post_id, :reviewer_actor_id], name: "index_post_reviews_on_post_id_and_reviewer_actor_id", unique: true)
      t.index(:post_review_status_id, name: "index_post_reviews_on_post_review_status_id")
      t.index(:reviewer_actor_id, name: "index_post_reviews_on_reviewer_actor_id", where: "(decided_at IS NULL)")
      t.check_constraint(
        "post_review_status_id IS NULL OR post_review_status_id >= 0",
        name: "chk_post_reviews_post_review_status_id_positive",
      )
    end

    create_table(:post_versions) do |t| # implicit id: :bigint
      t.text(:body)
      t.datetime(:created_at, null: false)
      t.string(:description)
      t.bigint(:edited_by_id)
      t.string(:edited_by_type)
      t.datetime(:expires_at, null: false)
      t.string(:permalink, limit: 200, null: false)
      t.bigint(:post_id, null: false) # FK
      t.string(:public_id, default: "", null: false)
      t.datetime(:publish_at, null: false)
      t.string(:redirect_url)
      t.string(:response_mode, null: false)
      t.string(:title)
      t.datetime(:updated_at, null: false)

      t.index(
        [:post_id, :created_at], name: "index_post_versions_on_post_id_and_created_at",
                                 order: { created_at: :desc },
      )
      t.index(:public_id, name: "index_post_versions_on_public_id", unique: true)
    end

    create_table(:avatar_assignments) do |t| # implicit id: :bigint
      t.bigint(:avatar_id, null: false) # FK
      t.datetime(:created_at, null: false)
      t.string(:role, limit: 50, default: "viewer", null: false)
      t.datetime(:updated_at, null: false)
      t.bigint(:user_id, null: false) # External UUID

      t.index(%i(avatar_id user_id role), name: "index_avatar_assignments_unique", unique: true)
      t.index(
        :avatar_id, name: "index_avatar_assignments_unique_affiliation", unique: true,
                    where: "((role)::text = 'affiliation'::text)",
      )
      t.index(
        :avatar_id, name: "index_avatar_assignments_unique_owner", unique: true,
                    where: "((role)::text = 'owner'::text)",
      )
      t.index(:user_id, name: "index_avatar_assignments_on_user_id")
      t.check_constraint(
        "role::text = ANY (ARRAY['owner'::character varying::text, 'affiliation'::character varying::text, 'administrator'::character varying::text, 'editor'::character varying::text, 'reviewer'::character varying::text, 'viewer'::character varying::text])",
        name: "check_avatar_assignment_role",
      )
    end

    create_table(:avatar_blocks) do |t| # implicit id: :bigint
      t.bigint(:blocked_avatar_id, null: false) # FK
      t.bigint(:blocker_avatar_id, null: false) # FK
      t.datetime(:created_at, null: false)
      t.datetime(:expires_at)
      t.string(:reason)
      t.datetime(:updated_at, null: false)

      t.index(:blocked_avatar_id, name: "index_avatar_blocks_on_blocked_avatar_id")
      t.index(:blocker_avatar_id, name: "index_avatar_blocks_on_blocker_avatar_id")
    end

    create_table(:avatar_follows) do |t| # implicit id: :bigint
      t.datetime(:created_at, null: false)
      t.bigint(:followed_avatar_id, null: false) # FK
      t.bigint(:follower_avatar_id, null: false) # FK
      t.datetime(:updated_at, null: false)

      t.index(:followed_avatar_id, name: "index_avatar_follows_on_followed_avatar_id")
      t.index(:follower_avatar_id, name: "index_avatar_follows_on_follower_avatar_id")
    end

    create_table(:avatar_mutes) do |t| # implicit id: :bigint
      t.datetime(:created_at, null: false)
      t.datetime(:expires_at)
      t.bigint(:muted_avatar_id, null: false) # FK
      t.bigint(:muter_avatar_id, null: false) # FK
      t.datetime(:updated_at, null: false)

      t.index(:muted_avatar_id, name: "index_avatar_mutes_on_muted_avatar_id")
      t.index(:muter_avatar_id, name: "index_avatar_mutes_on_muter_avatar_id")
    end

    create_table(:avatar_role_permissions) do |t| # implicit id: :bigint
      t.integer(:avatar_permission_id, limit: 2, default: 0, null: false)
      t.integer(:avatar_role_id, limit: 2, default: 0, null: false)
      t.timestamps

      t.index(:avatar_permission_id, name: "index_avatar_role_permissions_on_avatar_permission_id")
      t.index([:avatar_role_id, :avatar_permission_id], name: "uniq_avatar_role_permissions", unique: true)
      t.index(:avatar_role_id, name: "index_avatar_role_permissions_on_avatar_role_id")
      t.check_constraint("avatar_permission_id >= 0", name: "chk_avatar_role_permissions_permission_id_positive")
      t.check_constraint("avatar_role_id >= 0", name: "chk_avatar_role_permissions_role_id_positive")
    end

    # Client Avatar tables (refs avatar_id: bigint)

    create_table(:client_avatar_accesses) do |t|
      t.bigint(:avatar_id, null: false)
      t.bigint(:client_id, null: false)
      t.datetime(:created_at, null: false)
      t.datetime(:updated_at, null: false)

      t.index(:avatar_id, name: "index_client_avatar_accesses_on_avatar_id")
      t.index(:client_id, name: "index_client_avatar_accesses_on_client_id")
      t.index([:client_id, :avatar_id], name: "index_client_avatar_accesses_on_client_id_and_avatar_id", unique: true)
    end

    create_table(:client_avatar_deletions) do |t|
      t.bigint(:avatar_id, null: false)
      t.bigint(:client_id, null: false)
      t.datetime(:created_at, null: false)
      t.datetime(:updated_at, null: false)

      t.index(:avatar_id, name: "index_client_avatar_deletions_on_avatar_id")
      t.index(:client_id, name: "index_client_avatar_deletions_on_client_id")
      t.index([:client_id, :avatar_id], name: "index_client_avatar_deletions_on_client_and_avatar", unique: true)
    end

    create_table(:client_avatar_extractions) do |t|
      t.bigint(:avatar_id, null: false)
      t.bigint(:client_id, null: false)
      t.datetime(:created_at, null: false)
      t.datetime(:updated_at, null: false)

      t.index(:avatar_id, name: "index_client_avatar_extractions_on_avatar_id")
      t.index(:client_id, name: "index_client_avatar_extractions_on_client_id")
      t.index([:client_id, :avatar_id], name: "index_client_avatar_extractions_on_client_and_avatar", unique: true)
    end

    create_table(:client_avatar_impersonations) do |t|
      t.bigint(:avatar_id, null: false)
      t.bigint(:client_id, null: false)
      t.datetime(:created_at, null: false)
      t.datetime(:updated_at, null: false)

      t.index(:avatar_id, name: "index_client_avatar_impersonations_on_avatar_id")
      t.index(:client_id, name: "index_client_avatar_impersonations_on_client_id")
      t.index([:client_id, :avatar_id], name: "index_client_avatar_impersonations_on_client_and_avatar", unique: true)
    end

    create_table(:client_avatar_oversights) do |t|
      t.bigint(:avatar_id, null: false)
      t.bigint(:client_id, null: false)
      t.datetime(:created_at, null: false)
      t.datetime(:updated_at, null: false)

      t.index(:avatar_id, name: "index_client_avatar_oversights_on_avatar_id")
      t.index(:client_id, name: "index_client_avatar_oversights_on_client_id")
      t.index([:client_id, :avatar_id], name: "index_client_avatar_oversights_on_client_and_avatar", unique: true)
    end

    create_table(:client_avatar_suspensions) do |t|
      t.bigint(:avatar_id, null: false)
      t.bigint(:client_id, null: false)
      t.datetime(:created_at, null: false)
      t.datetime(:updated_at, null: false)

      t.index(:avatar_id, name: "index_client_avatar_suspensions_on_avatar_id")
      t.index(:client_id, name: "index_client_avatar_suspensions_on_client_id")
      t.index([:client_id, :avatar_id], name: "index_client_avatar_suspensions_on_client_and_avatar", unique: true)
    end

    create_table(:client_avatar_visibilities) do |t|
      t.bigint(:avatar_id, null: false)
      t.bigint(:client_id, null: false)
      t.datetime(:created_at, null: false)
      t.datetime(:updated_at, null: false)

      t.index(:avatar_id, name: "index_client_avatar_visibilities_on_avatar_id")
      t.index(:client_id, name: "index_client_avatar_visibilities_on_client_id")
      t.index([:client_id, :avatar_id], name: "index_client_avatar_visibilities_on_client_and_avatar", unique: true)
    end

    # Foreign Keys
    safety_assured do
      add_foreign_key(:avatar_assignments, :avatars, on_delete: :cascade)
      add_foreign_key(:avatar_blocks, :avatars, column: :blocked_avatar_id)
      add_foreign_key(:avatar_blocks, :avatars, column: :blocker_avatar_id)
      add_foreign_key(:avatar_follows, :avatars, column: :followed_avatar_id)
      add_foreign_key(:avatar_follows, :avatars, column: :follower_avatar_id)
      add_foreign_key(:avatar_memberships, :avatar_membership_statuses)
      add_foreign_key(:avatar_memberships, :avatar_roles, column: :role_id)
      add_foreign_key(:avatar_memberships, :avatars)
      add_foreign_key(:avatar_monikers, :avatar_moniker_statuses)
      add_foreign_key(:avatar_monikers, :avatars)
      add_foreign_key(:avatar_mutes, :avatars, column: :muted_avatar_id)
      add_foreign_key(:avatar_mutes, :avatars, column: :muter_avatar_id)
      add_foreign_key(:avatar_ownership_periods, :avatar_ownership_statuses)
      add_foreign_key(:avatar_ownership_periods, :avatars)
      add_foreign_key(:avatar_role_permissions, :avatar_permissions)
      add_foreign_key(:avatar_role_permissions, :avatar_roles)
      add_foreign_key(:avatars, :avatar_capabilities, column: :capability_id)
      add_foreign_key(:avatars, :handles, column: :active_handle_id)
      add_foreign_key(:client_avatar_accesses, :avatars)
      add_foreign_key(:client_avatar_deletions, :avatars)
      add_foreign_key(:client_avatar_extractions, :avatars)
      add_foreign_key(:client_avatar_impersonations, :avatars)
      add_foreign_key(:client_avatar_oversights, :avatars)
      add_foreign_key(:client_avatar_suspensions, :avatars)
      add_foreign_key(:client_avatar_visibilities, :avatars)
      add_foreign_key(:handle_assignments, :avatars)
      add_foreign_key(:handle_assignments, :handle_assignment_statuses)
      add_foreign_key(:handle_assignments, :handles)
      add_foreign_key(:handles, :handle_statuses)
      add_foreign_key(:post_reviews, :post_review_statuses)
      add_foreign_key(:post_reviews, :posts)
      add_foreign_key(:post_versions, :posts)
      add_foreign_key(:posts, :avatars, column: :author_avatar_id)
      add_foreign_key(:posts, :post_statuses)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
