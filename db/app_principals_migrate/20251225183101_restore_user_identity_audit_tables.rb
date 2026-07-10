# frozen_string_literal: true

class RestoreUserIdentityAuditTables < ActiveRecord::Migration[7.1]
  def change
    # Recreate User Identity Audit Tables
    create_table(:user_identity_audit_events, force: :cascade) do |t|
      t.timestamps
    end

    create_table(:user_identity_audit_levels, force: :cascade) do |t|
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
    end

    create_table(:user_identity_audits, force: :cascade) do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.string("actor_type", default: "", null: false)
      t.datetime("created_at", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.string("ip_address", default: "", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.bigint("subject_id")
      t.string("subject_type", default: "", null: false)
      t.text("previous_value")
      t.datetime("timestamp", null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.index(["event_id"], name: "index_user_identity_audits_on_event_id")
      t.index(["level_id"], name: "index_user_identity_audits_on_level_id")
      t.index(["user_id"], name: "index_user_identity_audits_on_user_id")
    end
  end
end
