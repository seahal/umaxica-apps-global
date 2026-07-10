# frozen_string_literal: true

class LoadInitialAppSettingSchema < ActiveRecord::Migration[8.2]
  def up
    load Rails.root.join("db/initial_schemas/app_setting.rb")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
