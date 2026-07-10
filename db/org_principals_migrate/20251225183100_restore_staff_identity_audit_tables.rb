# frozen_string_literal: true

class RestoreStaffIdentityAuditTables < ActiveRecord::Migration[7.1]
  def change
    # Recreate Staff Identity Audit Tables
    create_table(:staff_identity_audit_events, id: :string, force: :cascade) do |t|
      t.timestamps
    end

    create_table(:staff_identity_audit_levels, id: :string, force: :cascade) do |t|
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
    end

    create_table(:staff_identity_audits, force: :cascade) do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.string("actor_type", default: "", null: false)
      t.datetime("created_at", null: false)
      t.string("event_id", default: "NONE", null: false)
      t.string("ip_address", default: "", null: false)
      t.string("level_id", default: "NONE", null: false)
      t.bigint("subject_id")
      t.string("subject_type", default: "", null: false)
      t.text("previous_value")
      t.bigint("staff_id", null: false)
      t.datetime("timestamp", null: false)
      t.datetime("updated_at", null: false)
      t.index(["event_id"], name: "index_staff_identity_audits_on_event_id")
      t.index(["level_id"], name: "index_staff_identity_audits_on_level_id")
      t.index(["staff_id"], name: "index_staff_identity_audits_on_staff_id")
    end
  end
end
