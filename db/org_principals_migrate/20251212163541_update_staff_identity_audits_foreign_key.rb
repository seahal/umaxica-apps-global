# frozen_string_literal: true

class UpdateStaffIdentityAuditsForeignKey < ActiveRecord::Migration[8.2]
  def change
    return unless table_exists?(:staff_identity_audits)
    return unless table_exists?(:staff_identity_audit_statuses)

    # Since the table has been renamed, FK is automatically updated
    # If there is a problem with FK, recreate it explicitly
    return if foreign_key_exists?(:staff_identity_audits, column: :status_id)

    if foreign_key_exists?(:staff_identity_audits, :staff_identity_audit_statuses)
      remove_foreign_key(:staff_identity_audits, :staff_identity_audit_statuses)
    end
    add_foreign_key(:staff_identity_audits, :staff_identity_audit_statuses, column: :status_id)

  end
end
