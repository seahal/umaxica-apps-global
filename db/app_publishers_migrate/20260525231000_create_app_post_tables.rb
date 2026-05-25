# frozen_string_literal: true

class CreateAppPostTables < ActiveRecord::Migration[8.2]
  def change
    create_post_tables
  end

  private

  def create_post_tables
    create_table(:post_statuses, id: :bigint)

    create_table(:post_review_statuses, id: :bigint)

    create_table(:post_category_masters, id: :bigint) do |t|
      t.bigint(:parent_id, default: 0, null: false)
    end
    add_index(:post_category_masters, :parent_id)
    add_check_constraint(:post_category_masters, "parent_id >= 0", name: "post_category_masters_parent_id_non_negative")

    create_table(:post_tag_masters, id: :bigint) do |t|
      t.bigint(:parent_id, default: 0, null: false)
    end
    add_index(:post_tag_masters, :parent_id)
    add_check_constraint(:post_tag_masters, "parent_id >= 0", name: "post_tag_masters_parent_id_non_negative")

    create_table(:posts) do |t|
      t.bigint(:author_avatar_id, null: false)
      t.text(:body, null: false)
      t.bigint(:created_by_actor_id, null: false)
      t.timestamptz(:expires_at, null: false)
      t.bigint(:latest_revision_id)
      t.bigint(:latest_version_id)
      t.integer(:lock_version, default: 0, null: false)
      t.string(:permalink, limit: 200, null: false)
      t.integer(:position, default: 0, null: false)
      t.bigint(:post_status_id, null: false)
      t.string(:public_id, null: false)
      t.timestamptz(:published_at, null: false)
      t.bigint(:published_by_actor_id)
      t.string(:redirect_url)
      t.string(:response_mode, default: "html", null: false)
      t.string(:revision_key, null: false)
      t.timestamps
    end
    add_index(:posts, [:author_avatar_id, :created_at], order: { created_at: :desc })
    add_index(:posts, :latest_revision_id, unique: true)
    add_index(:posts, :latest_version_id, unique: true)
    add_index(:posts, :permalink, unique: true)
    add_index(:posts, :post_status_id)
    add_index(:posts, :public_id, unique: true)
    add_index(:posts, [:published_at, :expires_at])
    add_foreign_key(:posts, :post_statuses, validate: false)

    create_table(:post_categories) do |t|
      t.bigint(:post_category_master_id, default: 0, null: false)
      t.bigint(:post_id, null: false)
      t.timestamps
    end
    add_index(:post_categories, :post_category_master_id)
    add_index(:post_categories, :post_id, unique: true)
    add_check_constraint(:post_categories, "post_category_master_id >= 0", name: "post_categories_master_id_non_negative")
    add_foreign_key(:post_categories, :post_category_masters, validate: false)
    add_foreign_key(:post_categories, :posts, on_delete: :cascade, validate: false)

    create_table(:post_tags) do |t|
      t.bigint(:post_id, null: false)
      t.bigint(:post_tag_master_id, default: 0, null: false)
      t.timestamps
    end
    add_index(:post_tags, :post_id)
    add_index(:post_tags, [:post_tag_master_id, :post_id], unique: true)
    add_check_constraint(:post_tags, "post_tag_master_id >= 0", name: "post_tags_master_id_non_negative")
    add_foreign_key(:post_tags, :post_tag_masters, validate: false)
    add_foreign_key(:post_tags, :posts, on_delete: :cascade, validate: false)

    create_table(:post_reviews) do |t|
      t.text(:comment)
      t.timestamptz(:decided_at)
      t.bigint(:post_id, null: false)
      t.bigint(:post_review_status_id, null: false)
      t.bigint(:reviewer_actor_id, null: false)
      t.timestamps
    end
    add_index(:post_reviews, [:post_id, :reviewer_actor_id], unique: true)
    add_index(:post_reviews, :post_review_status_id)
    add_index(:post_reviews, :reviewer_actor_id, where: "decided_at IS NULL")
    add_foreign_key(:post_reviews, :post_review_statuses, validate: false)
    add_foreign_key(:post_reviews, :posts, validate: false)

    create_table(:post_versions) do |t|
      t.text(:body)
      t.string(:description)
      t.bigint(:edited_by_id)
      t.string(:edited_by_type)
      t.datetime(:expires_at, null: false)
      t.string(:permalink, limit: 200, null: false)
      t.bigint(:post_id, null: false)
      t.string(:public_id, default: "", null: false)
      t.datetime(:publish_at, null: false)
      t.string(:redirect_url)
      t.string(:response_mode, null: false)
      t.string(:title)
      t.timestamps
    end
    add_index(:post_versions, [:post_id, :created_at], order: { created_at: :desc })
    add_index(:post_versions, :public_id, unique: true)
    add_foreign_key(:post_versions, :posts, on_delete: :cascade, validate: false)

    create_table(:post_revisions) do |t|
      t.text(:body)
      t.string(:description)
      t.bigint(:edited_by_id)
      t.string(:edited_by_type)
      t.datetime(:expires_at, null: false)
      t.string(:permalink, limit: 200, null: false)
      t.bigint(:post_id, null: false)
      t.string(:public_id, default: "", null: false)
      t.datetime(:publish_at, null: false)
      t.string(:redirect_url)
      t.string(:response_mode, null: false)
      t.string(:title)
      t.timestamps
    end
    add_index(:post_revisions, [:post_id, :created_at], order: { created_at: :desc })
    add_index(:post_revisions, :public_id, unique: true)
    add_foreign_key(:post_revisions, :posts, on_delete: :cascade, validate: false)

    add_foreign_key(:posts, :post_versions, column: :latest_version_id, on_delete: :nullify, validate: false)
    add_foreign_key(:posts, :post_revisions, column: :latest_revision_id, on_delete: :nullify, validate: false)
  end
end
