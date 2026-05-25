# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.2].define(version: 2026_05_25_231100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "post_categories", force: :cascade do |t|
    t.bigint "post_category_master_id", default: 0, null: false
    t.bigint "post_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_category_master_id"], name: "index_post_categories_on_post_category_master_id"
    t.index ["post_id"], name: "index_post_categories_on_post_id", unique: true
    t.check_constraint "post_category_master_id >= 0", name: "post_categories_master_id_non_negative"
  end

  create_table "post_category_masters", force: :cascade do |t|
    t.bigint "parent_id", default: 0, null: false
    t.index ["parent_id"], name: "index_post_category_masters_on_parent_id"
    t.check_constraint "parent_id >= 0", name: "post_category_masters_parent_id_non_negative"
  end

  create_table "post_review_statuses", force: :cascade do |t|
  end

  create_table "post_reviews", force: :cascade do |t|
    t.text "comment"
    t.datetime "decided_at", precision: nil
    t.bigint "post_id", null: false
    t.bigint "post_review_status_id", null: false
    t.bigint "reviewer_actor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "reviewer_actor_id"], name: "index_post_reviews_on_post_id_and_reviewer_actor_id", unique: true
    t.index ["post_review_status_id"], name: "index_post_reviews_on_post_review_status_id"
    t.index ["reviewer_actor_id"], name: "index_post_reviews_on_reviewer_actor_id", where: "(decided_at IS NULL)"
  end

  create_table "post_revisions", force: :cascade do |t|
    t.text "body"
    t.string "description"
    t.bigint "edited_by_id"
    t.string "edited_by_type"
    t.datetime "expires_at", null: false
    t.string "permalink", limit: 200, null: false
    t.bigint "post_id", null: false
    t.string "public_id", default: "", null: false
    t.datetime "publish_at", null: false
    t.string "redirect_url"
    t.string "response_mode", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "created_at"], name: "index_post_revisions_on_post_id_and_created_at", order: { created_at: :desc }
    t.index ["public_id"], name: "index_post_revisions_on_public_id", unique: true
  end

  create_table "post_statuses", force: :cascade do |t|
  end

  create_table "post_tag_masters", force: :cascade do |t|
    t.bigint "parent_id", default: 0, null: false
    t.index ["parent_id"], name: "index_post_tag_masters_on_parent_id"
    t.check_constraint "parent_id >= 0", name: "post_tag_masters_parent_id_non_negative"
  end

  create_table "post_tags", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "post_tag_master_id", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_post_tags_on_post_id"
    t.index ["post_tag_master_id", "post_id"], name: "index_post_tags_on_post_tag_master_id_and_post_id", unique: true
    t.check_constraint "post_tag_master_id >= 0", name: "post_tags_master_id_non_negative"
  end

  create_table "post_versions", force: :cascade do |t|
    t.text "body"
    t.string "description"
    t.bigint "edited_by_id"
    t.string "edited_by_type"
    t.datetime "expires_at", null: false
    t.string "permalink", limit: 200, null: false
    t.bigint "post_id", null: false
    t.string "public_id", default: "", null: false
    t.datetime "publish_at", null: false
    t.string "redirect_url"
    t.string "response_mode", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "created_at"], name: "index_post_versions_on_post_id_and_created_at", order: { created_at: :desc }
    t.index ["public_id"], name: "index_post_versions_on_public_id", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "author_avatar_id", null: false
    t.text "body", null: false
    t.bigint "created_by_actor_id", null: false
    t.datetime "expires_at", precision: nil, null: false
    t.bigint "latest_revision_id"
    t.bigint "latest_version_id"
    t.integer "lock_version", default: 0, null: false
    t.string "permalink", limit: 200, null: false
    t.integer "position", default: 0, null: false
    t.bigint "post_status_id", null: false
    t.string "public_id", null: false
    t.datetime "published_at", precision: nil, null: false
    t.bigint "published_by_actor_id"
    t.string "redirect_url"
    t.string "response_mode", default: "html", null: false
    t.string "revision_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_avatar_id", "created_at"], name: "index_posts_on_author_avatar_id_and_created_at", order: { created_at: :desc }
    t.index ["latest_revision_id"], name: "index_posts_on_latest_revision_id", unique: true
    t.index ["latest_version_id"], name: "index_posts_on_latest_version_id", unique: true
    t.index ["permalink"], name: "index_posts_on_permalink", unique: true
    t.index ["post_status_id"], name: "index_posts_on_post_status_id"
    t.index ["public_id"], name: "index_posts_on_public_id", unique: true
    t.index ["published_at", "expires_at"], name: "index_posts_on_published_at_and_expires_at"
  end

  add_foreign_key "post_categories", "post_category_masters"
  add_foreign_key "post_categories", "posts", on_delete: :cascade
  add_foreign_key "post_reviews", "post_review_statuses"
  add_foreign_key "post_reviews", "posts"
  add_foreign_key "post_revisions", "posts", on_delete: :cascade
  add_foreign_key "post_tags", "post_tag_masters"
  add_foreign_key "post_tags", "posts", on_delete: :cascade
  add_foreign_key "post_versions", "posts", on_delete: :cascade
  add_foreign_key "posts", "post_revisions", column: "latest_revision_id", on_delete: :nullify
  add_foreign_key "posts", "post_statuses"
  add_foreign_key "posts", "post_versions", column: "latest_version_id", on_delete: :nullify
end
