# frozen_string_literal: true

class DecommissionAppPublisherPostTables < ActiveRecord::Migration[8.2]
  def up
    %i[
      app_post_categorizations
      app_post_reviews
      app_post_revisions
      app_post_taggings
      app_post_versions
      app_posts
      app_post_categories
      app_post_tags
      app_post_review_statuses
      app_post_statuses
    ].each { |table_name| drop_table(table_name, force: :cascade) }
  end

  def down
    create_post_tables(:app)
  end

  private

  def create_post_tables(surface)
    prefix = "#{surface}_post"

    create_table(:"#{prefix}_statuses", id: :bigint)
    create_table(:"#{prefix}_review_statuses", id: :bigint)

    create_tree_table(:"#{prefix}_categories")
    create_tree_table(:"#{prefix}_tags")
    create_posts_table(surface, prefix)
    create_categorization_table(surface, prefix)
    create_tagging_table(surface, prefix)
    create_review_table(surface, prefix)
    create_snapshot_table(surface, prefix, :versions)
    create_snapshot_table(surface, prefix, :revisions)

    add_foreign_key(:"#{prefix}s", :"#{prefix}_versions", column: :"latest_#{prefix}_version_id", on_delete: :nullify)
    add_foreign_key(:"#{prefix}s", :"#{prefix}_revisions", column: :"latest_#{prefix}_revision_id", on_delete: :nullify)
  end

  def create_tree_table(table_name)
    create_table(table_name, id: :bigint) do |t|
      t.bigint(:parent_id, default: 0, null: false)
      t.index(:parent_id)
    end
    add_check_constraint(table_name, "parent_id >= 0", name: "#{table_name}_parent_id_non_negative")
  end

  def create_posts_table(surface, prefix)
    table_name = :"#{prefix}s"
    create_table(table_name) do |t|
      t.bigint(:author_avatar_id, null: false)
      t.text(:body, null: false)
      t.bigint(:created_by_actor_id, null: false)
      t.timestamptz(:expires_at, null: false)
      t.bigint(:"latest_#{prefix}_revision_id")
      t.bigint(:"latest_#{prefix}_version_id")
      t.integer(:lock_version, default: 0, null: false)
      t.string(:permalink, limit: 200, null: false)
      t.integer(:position, default: 0, null: false)
      t.bigint(:"#{prefix}_status_id", null: false)
      t.string(:public_id, null: false)
      t.timestamptz(:published_at, null: false)
      t.bigint(:published_by_actor_id)
      t.string(:redirect_url)
      t.string(:response_mode, default: "html", null: false)
      t.string(:revision_key, null: false)
      t.timestamps
      t.index([:author_avatar_id, :created_at], order: { created_at: :desc })
      t.index(:"latest_#{prefix}_revision_id", unique: true)
      t.index(:"latest_#{prefix}_version_id", unique: true)
      t.index(:permalink, unique: true)
      t.index(:"#{prefix}_status_id")
      t.index(:public_id, unique: true)
      t.index([:published_at, :expires_at])
    end
    add_foreign_key(table_name, :"#{prefix}_statuses")
    add_post_response_constraints(table_name, "#{surface}_posts")
  end

  def create_categorization_table(surface, prefix)
    table_name = :"#{prefix}_categorizations"
    create_table(table_name) do |t|
      t.bigint(:"#{prefix}_category_id", default: 0, null: false)
      t.bigint(:"#{prefix}_id", null: false)
      t.timestamps
      t.index(:"#{prefix}_category_id")
      t.index(:"#{prefix}_id", unique: true)
    end
    add_check_constraint(table_name, "#{prefix}_category_id >= 0", name: "#{surface}_post_categories_master_id_non_negative")
    add_foreign_key(table_name, :"#{prefix}_categories")
    add_foreign_key(table_name, :"#{prefix}s", on_delete: :cascade)
  end

  def create_tagging_table(surface, prefix)
    table_name = :"#{prefix}_taggings"
    create_table(table_name) do |t|
      t.bigint(:"#{prefix}_id", null: false)
      t.bigint(:"#{prefix}_tag_id", default: 0, null: false)
      t.timestamps
      t.index(:"#{prefix}_id")
      t.index([:"#{prefix}_tag_id", :"#{prefix}_id"], unique: true)
    end
    add_check_constraint(table_name, "#{prefix}_tag_id >= 0", name: "#{surface}_post_tags_master_id_non_negative")
    add_foreign_key(table_name, :"#{prefix}_tags")
    add_foreign_key(table_name, :"#{prefix}s", on_delete: :cascade)
  end

  def create_review_table(_surface, prefix)
    table_name = :"#{prefix}_reviews"
    create_table(table_name) do |t|
      t.text(:comment)
      t.timestamptz(:decided_at)
      t.bigint(:"#{prefix}_id", null: false)
      t.bigint(:"#{prefix}_review_status_id", null: false)
      t.bigint(:reviewer_actor_id, null: false)
      t.timestamps
      t.index([:"#{prefix}_id", :reviewer_actor_id], unique: true)
      t.index(:"#{prefix}_review_status_id")
      t.index(:reviewer_actor_id, where: "decided_at IS NULL")
    end
    add_foreign_key(table_name, :"#{prefix}_review_statuses")
    add_foreign_key(table_name, :"#{prefix}s")
  end

  def create_snapshot_table(surface, prefix, kind)
    table_name = :"#{prefix}_#{kind}"
    create_table(table_name) do |t|
      t.text(:body)
      t.string(:description)
      t.bigint(:edited_by_id)
      t.string(:edited_by_type)
      t.datetime(:expires_at, null: false)
      t.string(:permalink, limit: 200, null: false)
      t.bigint(:"#{prefix}_id", null: false)
      t.string(:public_id, default: "", null: false)
      t.datetime(:publish_at, null: false)
      t.string(:redirect_url)
      t.string(:response_mode, null: false)
      t.string(:title)
      t.timestamps
      t.index([:"#{prefix}_id", :created_at], order: { created_at: :desc })
      t.index(:public_id, unique: true)
    end
    add_foreign_key(table_name, :"#{prefix}s", on_delete: :cascade)
    add_post_response_constraints(table_name, "#{surface}_post_#{kind}")
  end

  def add_post_response_constraints(table_name, constraint_prefix)
    add_check_constraint(table_name, "response_mode IN ('html', 'json', 'redirect')", name: "chk_#{constraint_prefix}_response_mode")
    add_check_constraint(
      table_name,
      "response_mode <> 'redirect' OR redirect_url IS NOT NULL",
      name: "chk_#{constraint_prefix}_redirect_url_for_redirect",
    )
  end
end
