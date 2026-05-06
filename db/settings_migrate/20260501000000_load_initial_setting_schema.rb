# frozen_string_literal: true

class LoadInitialSettingSchema < ActiveRecord::Migration[8.2]
  def up
    load Rails.root.join("db/initial_schemas/setting.rb")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
