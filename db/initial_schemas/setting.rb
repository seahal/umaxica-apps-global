# frozen_string_literal: true

ActiveRecord::Schema[8.2].define(version: 20_260_331_222_105) do
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "com_preference_binding_methods", force: :cascade do |t|
  end

  create_table "com_preference_colortheme_options", force: :cascade do |t|
  end

  create_table "com_preference_colorthemes", force: :cascade do |t|
    t.datetime("created_at", null: false)
    t.bigint("option_id", null: false)
    t.bigint("preference_id", null: false)
    t.datetime("updated_at", null: false)
    t.index(["option_id"], name: "index_com_preference_colorthemes_on_option_id")
    t.index(["preference_id"], name: "index_com_preference_colorthemes_on_preference_id", unique: true)
  end

  create_table "com_preference_cookies", force: :cascade do |t|
    t.uuid("consent_version")
    t.boolean("consented", default: false, null: false)
    t.datetime("consented_at")
    t.datetime("created_at", null: false)
    t.boolean("functional", default: false, null: false)
    t.boolean("performant", default: false, null: false)
    t.bigint("preference_id", null: false)
    t.boolean("targetable", default: false, null: false)
    t.datetime("updated_at", null: false)
    t.index(["preference_id"], name: "index_com_preference_cookies_on_preference_id", unique: true)
  end

  create_table "com_preference_dbsc_statuses", force: :cascade do |t|
  end

  create_table "com_preference_language_options", force: :cascade do |t|
  end

  create_table "com_preference_languages", force: :cascade do |t|
    t.datetime("created_at", null: false)
    t.bigint("option_id", null: false)
    t.bigint("preference_id", null: false)
    t.datetime("updated_at", null: false)
    t.index(["option_id"], name: "index_com_preference_languages_on_option_id")
    t.index(["preference_id"], name: "index_com_preference_languages_on_preference_id", unique: true)
  end

  create_table "com_preference_regions", force: :cascade do |t|
    t.datetime("created_at", null: false)
    t.bigint("option_id", null: false)
    t.bigint("preference_id", null: false)
    t.datetime("updated_at", null: false)
    t.index(["option_id"], name: "index_com_preference_regions_on_option_id")
    t.index(["preference_id"], name: "index_com_preference_regions_on_preference_id", unique: true)
  end

  create_table "com_preference_region_options", force: :cascade do |t|
  end

  create_table "com_preference_statuses", force: :cascade do |t|
  end

  create_table "com_preference_timezone_options", force: :cascade do |t|
  end

  create_table "com_preference_timezones", force: :cascade do |t|
    t.datetime("created_at", null: false)
    t.bigint("option_id", null: false)
    t.bigint("preference_id", null: false)
    t.datetime("updated_at", null: false)
    t.index(["option_id"], name: "index_com_preference_timezones_on_option_id")
    t.index(["preference_id"], name: "index_com_preference_timezones_on_preference_id", unique: true)
  end

  create_table "com_preferences", force: :cascade do |t|
    t.bigint("binding_method_id", default: 0, null: false)
    t.datetime("compromised_at")
    t.datetime("created_at", null: false)
    t.text("dbsc_challenge")
    t.datetime("dbsc_challenge_issued_at")
    t.jsonb("dbsc_public_key")
    t.string("dbsc_session_id")
    t.bigint("dbsc_status_id", default: 0, null: false)
    t.string("device_id")
    t.string("device_id_digest")
    t.datetime("expires_at")
    t.string("jti")
    t.string("public_id", null: false)
    t.bigint("replaced_by_id")
    t.datetime("revoked_at")
    t.bigint("status_id", default: 2, null: false)
    t.binary("token_digest")
    t.datetime("updated_at", null: false)
    t.datetime("used_at")
    t.index(["binding_method_id"], name: "index_com_preferences_on_binding_method_id")
    t.index(["dbsc_session_id"], name: "index_com_preferences_on_dbsc_session_id", unique: true)
    t.index(["dbsc_status_id"], name: "index_com_preferences_on_dbsc_status_id")
    t.index(["device_id"], name: "index_com_preferences_on_device_id")
    t.index(["device_id_digest"], name: "index_com_preferences_on_device_id_digest")
    t.index(["jti"], name: "index_com_preferences_on_jti", unique: true)
    t.index(["public_id"], name: "index_com_preferences_on_public_id", unique: true)
    t.index(["replaced_by_id"], name: "index_com_preferences_on_replaced_by_id")
    t.index(["revoked_at"], name: "index_com_preferences_on_revoked_at")
    t.index(["status_id"], name: "index_com_preferences_on_status_id")
    t.index(["token_digest"], name: "index_com_preferences_on_token_digest")
    t.index(["used_at"], name: "index_com_preferences_on_used_at")
  end

  add_foreign_key "com_preference_colorthemes", "com_preference_colortheme_options", column: "option_id", name: "fk_com_preference_colorthemes_on_option_id", validate: false
  add_foreign_key "com_preference_colorthemes", "com_preferences", column: "preference_id", validate: false
  add_foreign_key "com_preference_cookies", "com_preferences", column: "preference_id", validate: false
  add_foreign_key "com_preference_languages", "com_preference_language_options", column: "option_id", name: "fk_com_preference_languages_on_option_id", validate: false
  add_foreign_key "com_preference_languages", "com_preferences", column: "preference_id", validate: false
  add_foreign_key "com_preference_regions", "com_preference_region_options", column: "option_id", name: "fk_com_preference_regions_on_option_id", validate: false
  add_foreign_key "com_preference_regions", "com_preferences", column: "preference_id", validate: false
  add_foreign_key "com_preference_timezones", "com_preference_timezone_options", column: "option_id", name: "fk_com_preference_timezones_on_option_id", validate: false
  add_foreign_key "com_preference_timezones", "com_preferences", column: "preference_id", validate: false
  add_foreign_key "com_preferences", "com_preference_binding_methods", column: "binding_method_id", name: "fk_com_preferences_on_binding_method_id", validate: false
  add_foreign_key "com_preferences", "com_preference_dbsc_statuses", column: "dbsc_status_id", name: "fk_com_preferences_on_dbsc_status_id", validate: false
  add_foreign_key "com_preferences", "com_preference_statuses", column: "status_id", name: "fk_com_preferences_on_status_id", validate: false
  add_foreign_key "com_preferences", "com_preferences", column: "replaced_by_id", on_delete: :nullify, validate: false
end
