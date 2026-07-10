# frozen_string_literal: true

class AddWithdrawnAtToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column(:users, :withdrawn_at, :datetime) unless column_exists?(:users, :withdrawn_at)
  end
end
