# frozen_string_literal: true

class RenameStaffStatusIdToStaffIdentityStatusId < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    return unless column_exists?(:staffs, :staff_status_id)

    if foreign_key_exists?(:staffs, column: :staff_status_id)
      remove_foreign_key(:staffs, column: :staff_status_id)
    end

    rename_column(:staffs, :staff_status_id, :staff_identity_status_id)

    if index_exists?(:staffs, :staff_identity_status_id, name: 'index_staffs_on_staff_status_id')
      remove_index(:staffs, name: 'index_staffs_on_staff_status_id')
    elsif index_exists?(:staffs, :staff_status_id)
      remove_index(:staffs, :staff_status_id)
    end

    unless index_exists?(:staffs, :staff_identity_status_id, name: 'index_staffs_on_staff_identity_status_id')
      add_index(:staffs, :staff_identity_status_id, name: 'index_staffs_on_staff_identity_status_id')
    end

    return if foreign_key_exists?(:staffs, column: :staff_identity_status_id)

    add_foreign_key(:staffs, :staff_identity_statuses, column: :staff_identity_status_id, primary_key: :id)

  end

  def down
    return unless column_exists?(:staffs, :staff_identity_status_id)

    remove_foreign_key(:staffs, column: :staff_identity_status_id) if foreign_key_exists?(
      :staffs,
      column: :staff_identity_status_id,
    )

    remove_index(:staffs, name: 'index_staffs_on_staff_identity_status_id') if index_exists?(
      :staffs,
      :staff_identity_status_id,
    )

    rename_column(:staffs, :staff_identity_status_id, :staff_status_id)

    add_index(:staffs, :staff_status_id, name: 'index_staffs_on_staff_status_id')
    add_foreign_key(:staffs, :staff_identity_statuses, column: :staff_status_id, primary_key: :id)
  end
end
