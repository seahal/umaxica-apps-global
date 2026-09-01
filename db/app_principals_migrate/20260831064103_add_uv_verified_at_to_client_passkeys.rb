# frozen_string_literal: true

class AddUvVerifiedAtToClientPasskeys < ActiveRecord::Migration[8.2]
  def change
    add_column(:client_passkeys, :uv_verified_at, :datetime)
  end
end
