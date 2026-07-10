# frozen_string_literal: true

class EnsureNilUserForFks < ActiveRecord::Migration[8.2]
  NULL_UUID = "00000000-0000-0000-0000-000000000000"
  NULL_PUBLIC_ID = "000000000000000000000"

  def up
    return unless table_exists?(:users)

    cols = connection.columns(:users).map(&:name)
    attrs = { id: NULL_UUID }
    attrs[:public_id] = NULL_PUBLIC_ID if cols.include?("public_id")
    attrs[:user_identity_status_id] = "NEYO" if cols.include?("user_identity_status_id")
    attrs[:webauthn_id] = "" if cols.include?("webauthn_id")
    attrs[:created_at] = Time.current if cols.include?("created_at")
    attrs[:updated_at] = Time.current if cols.include?("updated_at")

    safety_assured do
      # No-op: intentionally left blank.
    end
  end

  def down
    # No-op to avoid deleting shared test reference user.
  end
end
