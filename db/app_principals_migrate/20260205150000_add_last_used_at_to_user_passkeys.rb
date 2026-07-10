# frozen_string_literal: true

class AddLastUsedAtToUserPasskeys < ActiveRecord::Migration[8.2]
  def change
    add_column(:user_passkeys, :last_used_at, :datetime)
  end
end
