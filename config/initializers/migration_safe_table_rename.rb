# typed: false
# frozen_string_literal: true

ActiveSupport.on_load(:active_record) do
  require "migration_helpers/safe_table_rename"
  ActiveRecord::Migration.include(MigrationHelpers::SafeTableRename)
end
