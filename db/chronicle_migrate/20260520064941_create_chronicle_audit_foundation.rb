# frozen_string_literal: true

class CreateChronicleAuditFoundation < ActiveRecord::Migration[8.2]
  def change
    create_table :chronicle_retention_policies do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.integer :duration_days, null: false
      t.boolean :permanent, null: false

      t.timestamps
    end
    add_index :chronicle_retention_policies, :code, unique: true
    add_check_constraint(
      :chronicle_retention_policies,
      "permanent = false OR duration_days = 0",
      name: "chk_chronicle_retention_policies_permanent_duration"
    )

    create_table :chronicle_visibility_contexts do |t|
      t.string :code, null: false
      t.string :name, null: false

      t.timestamps
    end
    add_index :chronicle_visibility_contexts, :code, unique: true

    create_table :chronicles do |t|
      t.string :event_uuid, null: false
      t.references :actor, polymorphic: true, null: true, index: true
      t.references :subject, polymorphic: true, null: true, index: true
      t.references :chronicle_retention_policy, null: false, foreign_key: true
      t.string :action, null: false
      t.string :result, null: false
      t.string :reason
      t.datetime :occurred_at, null: false
      t.datetime :erasable_at
      t.string :request_id
      t.inet :ip_address
      t.text :user_agent
      t.jsonb :metadata, null: false, default: {}
      t.jsonb :changeset, null: false, default: {}

      t.timestamps
    end
    add_index :chronicles, :event_uuid, unique: true
    add_index :chronicles, :action
    add_index :chronicles, :result
    add_index :chronicles, :occurred_at
    add_index :chronicles, :erasable_at
    add_index :chronicles, :request_id
    add_check_constraint(
      :chronicles,
      "result IN ('intent', 'succeeded', 'failed', 'audit_incomplete', 'invalidated', 'manual_recovery_required')",
      name: "chk_chronicles_result"
    )

    create_table :chronicle_visibilities do |t|
      t.references :chronicle, null: false, foreign_key: true
      t.references :chronicle_visibility_context, null: false, foreign_key: true

      t.timestamps
    end
    add_index(
      :chronicle_visibilities,
      %i(chronicle_id chronicle_visibility_context_id),
      unique: true,
      name: "idx_chronicle_visibilities_unique_context"
    )

    create_table :chronicle_outbox_entries do |t|
      t.references :chronicle, null: true, foreign_key: true
      t.string :event_uuid, null: false
      t.string :request_id
      t.string :event, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false

      t.timestamps
    end
    add_index :chronicle_outbox_entries, :event_uuid
    add_index :chronicle_outbox_entries, :status
  end
end
