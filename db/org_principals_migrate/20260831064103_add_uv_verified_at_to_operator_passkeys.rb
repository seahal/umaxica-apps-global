# frozen_string_literal: true

class AddUvVerifiedAtToOperatorPasskeys < ActiveRecord::Migration[8.2]
  def change
    add_column(:operator_passkeys, :uv_verified_at, :datetime)
  end
end
