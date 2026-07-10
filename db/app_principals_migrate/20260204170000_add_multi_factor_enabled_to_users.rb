# frozen_string_literal: true

class AddMultiFactorEnabledToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column(:users, :multi_factor_enabled, :boolean, null: false, default: false)
  end
end
