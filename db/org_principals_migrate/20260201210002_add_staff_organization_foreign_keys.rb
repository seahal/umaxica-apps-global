# frozen_string_literal: true

# Migration to add foreign keys for staff, organization, and department associations
# This resolves ForeignKeyChecker warnings for various operator associations
class AddStaffOrganizationForeignKeys < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    # StaffOneTimePassword associations
    add_foreign_key(
      :staff_one_time_passwords, :staffs,
      column: :staff_id,
      on_delete: :cascade,
      validate: false,
      if_not_exists: true,
    )

    add_foreign_key(
      :staff_one_time_passwords, :staff_one_time_password_statuses,
      column: :staff_one_time_password_status_id,
      on_delete: :restrict,
      validate: false,
      if_not_exists: true,
    )

    add_index(
      :staff_one_time_passwords, :staff_one_time_password_status_id,
      name: "idx_staff_otps_on_status_id",
      if_not_exists: true,
      algorithm: :concurrently,
    )

    # Organization status
    add_foreign_key(
      :organizations, :workspace_statuses,
      column: :workspace_status_id,
      on_delete: :restrict,
      validate: false,
      if_not_exists: true,
    )

    add_index(
      :organizations, :workspace_status_id,
      name: "index_organizations_on_workspace_status_id",
      if_not_exists: true,
      algorithm: :concurrently,
    )

    # Department associations
    add_foreign_key(
      :departments, :department_statuses,
      column: :department_status_id,
      on_delete: :restrict,
      validate: false,
      if_not_exists: true,
    )

    add_foreign_key(
      :departments, :workspaces,
      column: :workspace_id,
      on_delete: :nullify,
      validate: false,
      if_not_exists: true,
    )

    add_index(
      :departments, :department_status_id,
      name: "index_departments_on_department_status_id",
      if_not_exists: true,
      algorithm: :concurrently,
    )
    add_index(
      :departments, :workspace_id,
      name: "index_departments_on_workspace_id",
      if_not_exists: true,
      algorithm: :concurrently,
    )
  end
end
