# frozen_string_literal: true

class RenameStaffTelephonesToStaffIdentityTelephones < ActiveRecord::Migration[8.2]
  def up
    return unless table_exists?(:staff_telephones)

    rename_table(:staff_telephones, :staff_identity_telephones)

    # Check if index still has old name before renaming
    return unless index_exists?(:staff_identity_telephones, :staff_id, name: "index_staff_telephones_on_staff_id")

    rename_index(
      :staff_identity_telephones,
      "index_staff_telephones_on_staff_id",
      "index_staff_identity_telephones_on_staff_id",
    )

  end

  def down
    return unless table_exists?(:staff_identity_telephones)

    rename_index(
      :staff_identity_telephones,
      "index_staff_identity_telephones_on_staff_id",
      "index_staff_telephones_on_staff_id",
    )
    rename_table(:staff_identity_telephones, :staff_telephones)
  end
end
