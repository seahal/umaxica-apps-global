# frozen_string_literal: true

class AddLastUsedAtToStaffPasskeys < ActiveRecord::Migration[8.2]
  def change
    add_column(:staff_passkeys, :last_used_at, :datetime)
  end
end
