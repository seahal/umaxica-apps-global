# typed: false
# frozen_string_literal: true

module MigrationHelpers
  module SafeTableRename
    class InconsistentState < StandardError; end

    def rename_table_strict(old_table, new_table)
      old_exists = table_exists?(old_table)
      new_exists = table_exists?(new_table)

      if old_exists && !new_exists
        safety_assured { rename_table old_table, new_table }
      elsif !old_exists && new_exists
        say "  skipped: #{old_table} -> #{new_table} (already renamed)", true
      elsif old_exists && new_exists
        raise InconsistentState,
              "Cannot rename #{old_table} -> #{new_table}: both tables exist. " \
              "Resolve manually (likely a prior failed migration left orphan tables)."
      else
        raise InconsistentState,
              "Cannot rename #{old_table} -> #{new_table}: neither table exists. " \
              "Schema is out of sync with this migration."
      end
    end
  end
end
