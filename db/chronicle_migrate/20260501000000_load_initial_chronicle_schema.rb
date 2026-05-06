# frozen_string_literal: true

class LoadInitialChronicleSchema < ActiveRecord::Migration[8.2]
  def up
    load Rails.root.join("db/initial_schemas/chronicle.rb")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
