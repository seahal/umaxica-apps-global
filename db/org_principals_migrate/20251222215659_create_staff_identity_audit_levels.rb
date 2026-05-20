# frozen_string_literal: true

class CreateStaffIdentityAuditLevels < ActiveRecord::Migration[8.2]
  def change
    unless table_exists?(:staff_identity_audit_levels)
      create_table(:staff_identity_audit_levels, id: :string, default: "NONE") do |t|
        t.timestamps
      end
    end

    add_column(:staff_identity_audits, :level_id, :string, default: "NONE", null: false) unless column_exists?(
      :staff_identity_audits, :level_id,
    )
    add_index(:staff_identity_audits, :level_id) unless index_exists?(:staff_identity_audits, :level_id)
    add_foreign_key(:staff_identity_audits, :staff_identity_audit_levels, column: :level_id) unless foreign_key_exists?(
      :staff_identity_audits, column: :level_id,
    )
  end
end
