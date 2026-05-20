# frozen_string_literal: true

class LoadInitialComSettingSchema < ActiveRecord::Migration[8.2]
  def up
    load Rails.root.join("db/initial_schemas/com_setting.rb")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
