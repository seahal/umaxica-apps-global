# frozen_string_literal: true

class AddAuditEventIdIndexToStaffs < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    unless index_exists?(:staffs, :withdrawn_at, name: 'index_staffs_on_withdrawn_at')
      add_index(:staffs, :withdrawn_at, name: 'index_staffs_on_withdrawn_at', where: 'withdrawn_at IS NOT NULL')
    end

    return if index_exists?(:staff_identity_audits, :event_id, name: 'index_staff_identity_audits_on_event_id')

    add_index(:staff_identity_audits, :event_id, name: 'index_staff_identity_audits_on_event_id')

  end
end
