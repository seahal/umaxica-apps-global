# frozen_string_literal: true

class CreateVisitorPrivacyAndRetentionTables < ActiveRecord::Migration[8.2]
  def change
    create_table :visitor_privacy_request_statuses, id: false do |t|
      t.bigint :id, null: false, primary_key: true
      t.string :name, default: "", null: false
    end
    reversible { |dir| dir.up { seed_fixed_ids(:visitor_privacy_request_statuses, [10, 20, 30, 40, 50, 60, 70, 80, 90]) } }

    create_table :visitor_privacy_requests do |t|
      t.string :public_id, limit: 21, default: "", null: false
      t.references :visitor, null: false, foreign_key: true
      t.string :request_kind, default: "erasure", null: false
      t.string :jurisdiction, default: "unknown", null: false
      t.string :request_source, default: "self_service", null: false
      t.bigint :status_id, default: 10, null: false
      t.datetime :received_at, null: false
      t.datetime :verified_at
      t.datetime :processing_started_at
      t.datetime :response_due_at, null: false
      t.datetime :extended_until
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.string :denial_reason, default: "", null: false
      t.string :retention_exception_code, default: "", null: false
      t.datetime :legal_hold_blocked_at
      t.datetime :final_response_sent_at
      t.integer :lock_version, default: 0, null: false
      t.datetime :discarded_at, default: -> { "'infinity'" }, null: false
      t.datetime :purged_at, default: -> { "'infinity'" }, null: false
      t.timestamps

      t.index :public_id, unique: true
      t.index %i[visitor_id request_kind status_id], name: "idx_visitor_privacy_requests_subject_kind_status"
      t.index :response_due_at
      t.index :discarded_at
      t.index :purged_at, where: "purged_at < 'infinity'"
      t.check_constraint "discarded_at <= purged_at", name: "chk_visitor_privacy_requests_retention_order"
    end

    add_foreign_key :visitor_privacy_requests, :visitor_privacy_request_statuses, column: :status_id, validate: false

    create_table :visitor_retention_hold_statuses, id: false do |t|
      t.bigint :id, null: false, primary_key: true
      t.string :name, default: "", null: false
    end
    reversible { |dir| dir.up { seed_fixed_ids(:visitor_retention_hold_statuses, [10, 20, 30]) } }

    create_table :visitor_retention_holds do |t|
      t.string :public_id, limit: 21, default: "", null: false
      t.references :visitor, null: false, foreign_key: true
      t.string :hold_kind, default: "legal_hold", null: false
      t.string :reason_code, default: "legal_hold", null: false
      t.bigint :status_id, default: 10, null: false
      t.datetime :applied_at, null: false
      t.datetime :released_at
      t.datetime :expires_at
      t.string :applied_by_type, default: "", null: false
      t.string :applied_by_public_id, default: "", null: false
      t.string :memo, default: "", null: false
      t.datetime :discarded_at, default: -> { "'infinity'" }, null: false
      t.datetime :purged_at, default: -> { "'infinity'" }, null: false
      t.timestamps

      t.index :public_id, unique: true
      t.index %i[visitor_id status_id], name: "idx_visitor_retention_holds_on_subject_status"
      t.index :expires_at
      t.index :discarded_at
      t.index :purged_at, where: "purged_at < 'infinity'"
      t.check_constraint "discarded_at <= purged_at", name: "chk_visitor_retention_holds_retention_order"
    end

    add_foreign_key :visitor_retention_holds, :visitor_retention_hold_statuses, column: :status_id, validate: false

    create_table :visitor_processor_erasure_notification_statuses, id: false do |t|
      t.bigint :id, null: false, primary_key: true
      t.string :name, default: "", null: false
    end
    reversible { |dir| dir.up { seed_fixed_ids(:visitor_processor_erasure_notification_statuses, [10, 20, 30, 40]) } }

    create_table :visitor_processor_erasure_notifications do |t|
      t.string :public_id, limit: 21, default: "", null: false
      t.references :visitor_privacy_request, null: false, foreign_key: true
      t.string :processor_key, default: "", null: false
      t.bigint :status_id, default: 10, null: false
      t.datetime :requested_at, null: false
      t.datetime :notified_at
      t.datetime :failed_at
      t.string :last_error_code, default: "", null: false
      t.string :last_error_message, default: "", null: false
      t.integer :retry_count, default: 0, null: false
      t.datetime :next_retry_at
      t.datetime :discarded_at, default: -> { "'infinity'" }, null: false
      t.datetime :purged_at, default: -> { "'infinity'" }, null: false
      t.timestamps

      t.index :public_id, unique: true
      t.index %i[visitor_privacy_request_id processor_key],
              unique: true,
              name: "idx_visitor_proc_erase_notifications_unique"
      t.index %i[status_id next_retry_at], name: "idx_visitor_proc_erase_notifications_retry"
      t.index :discarded_at
      t.index :purged_at, where: "purged_at < 'infinity'"
      t.check_constraint "discarded_at <= purged_at", name: "chk_visitor_proc_erase_notifications_retention_order"
    end
  end

  private

  def seed_fixed_ids(table_name, ids)
    status_model =
      Class.new(ActiveRecord::Base) do
        self.table_name = table_name
      end

    ids.each { |id| status_model.create!(id: id) }
  end
end
