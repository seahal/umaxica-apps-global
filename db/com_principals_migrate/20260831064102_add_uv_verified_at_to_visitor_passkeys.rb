# frozen_string_literal: true

class AddUvVerifiedAtToVisitorPasskeys < ActiveRecord::Migration[8.2]
  def change
    add_column(:visitor_passkeys, :uv_verified_at, :datetime)
  end
end
