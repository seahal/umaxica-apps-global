# frozen_string_literal: true

require "digest"

class CreateStaffIdentityPasskeyStatuses < ActiveRecord::Migration[8.2]
  FORMAT_REGEX = "^[A-Z0-9_]+$"

  def up
    create_table(:staff_identity_passkey_statuses, id: :string, limit: 255, primary_key: :id)

    safety_assured do
      # No-op: intentionally left blank.
    end

    add_check_constraint(
      :staff_identity_passkey_statuses,
      "id IS NULL OR id ~ '#{FORMAT_REGEX}'",
      name: constraint_name(:staff_identity_passkey_statuses, :id),
    )

    add_index(
      :staff_identity_passkey_statuses, "lower(id)",
      unique: true,
      name: "index_staff_identity_passkey_statuses_on_lower_id",
      if_not_exists: true,
    )
  end

  def down
    drop_table(:staff_identity_passkey_statuses)
  end

  private

  def constraint_name(table, column)
    base = "chk_#{table}_#{column}_format"
    return base if base.length <= 63

    digest = Digest::SHA256.hexdigest(base)[0, 10]
    "chk_#{table}_#{column}_#{digest}"
  end
end
