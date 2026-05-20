# frozen_string_literal: true

class MigrateStaffPreferencesDataToOperator < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      migrate_staff_preferences_data
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def migrate_staff_preferences_data
    return unless source_table_exists?(:staff_preferences)

    # Copy staff_preferences
    execute(<<~SQL.squish)
      INSERT INTO staff_preferences (
        id, staff_id, consented, functional, performant, targetable,
        consented_at, consent_version, language, region, timezone, theme,
        created_at, updated_at
      )
      SELECT
        id, staff_id, consented, functional, performant, targetable,
        consented_at, consent_version, language, region, timezone, theme,
        created_at, updated_at
      FROM principal.staff_preferences
      ON CONFLICT (id) DO NOTHING
    SQL

    # Copy child tables
    copy_child_table_data(:staff_preference_languages)
    copy_child_table_data(:staff_preference_timezones)
    copy_child_table_data(:staff_preference_regions)
    copy_child_table_data(:staff_preference_colorthemes)
  end

  def source_table_exists?(table_name)
    execute(<<~SQL.squish).any?
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'principal'
      AND table_name = '#{table_name}'
    SQL
  rescue ActiveRecord::StatementInvalid
    false
  end

  def copy_child_table_data(table_name)
    return unless source_table_exists?(table_name)

    execute(<<~SQL.squish)
      INSERT INTO #{table_name} (
        id, preference_id, option_id, created_at, updated_at
      )
      SELECT
        id, preference_id, option_id, created_at, updated_at
      FROM principal.#{table_name}
      ON CONFLICT (id) DO NOTHING
    SQL
  end
end
