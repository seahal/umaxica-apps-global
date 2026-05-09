# frozen_string_literal: true

class AddDeletableAtToOrgPreferences < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      add_column(:org_preferences, :deletable_at, :datetime, null: false, default: -> { "'infinity'" })
    end
    add_index(:org_preferences, :deletable_at, algorithm: :concurrently)
  end

  def down
    remove_index(:org_preferences, :deletable_at, algorithm: :concurrently) if index_exists?(:org_preferences, :deletable_at)
    remove_column(:org_preferences, :deletable_at) if column_exists?(:org_preferences, :deletable_at)
  end
end
