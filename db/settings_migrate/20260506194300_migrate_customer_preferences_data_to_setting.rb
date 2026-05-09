# frozen_string_literal: true

class MigrateCustomerPreferencesDataToSetting < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      migrate_customer_preferences_data
    end
  end

  def down
    # This migration is not reversible as it would destroy data
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def migrate_customer_preferences_data
    # Check if source table exists (it may not exist in test environment)
    return unless source_table_exists?(:customer_preferences)

    # Copy data from guest.customer_preferences to setting.customer_preferences
    execute(<<~SQL.squish)
      INSERT INTO customer_preferences (
        id, consent_version, consented, consented_at, functional, language,
        performant, region, targetable, theme, timezone, customer_id,
        created_at, updated_at
      )
      SELECT
        id, consent_version, consented, consented_at, functional, language,
        performant, region, targetable, theme, timezone, customer_id,
        created_at, updated_at
      FROM guest.customer_preferences
      ON CONFLICT (id) DO NOTHING
    SQL

    # Copy child table data
    copy_child_table_data(:customer_preference_languages)
    copy_child_table_data(:customer_preference_timezones)
    copy_child_table_data(:customer_preference_regions)
    copy_child_table_data(:customer_preference_colorthemes)
  end

  def source_table_exists?(table_name)
    execute(<<~SQL.squish).any?
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'guest'
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
      FROM guest.#{table_name}
      ON CONFLICT (id) DO NOTHING
    SQL
  end
end
