# frozen_string_literal: true

class ConsolidateComPreferenceReferenceTables < ActiveRecord::Migration[8.2]
  REFERENCE_TABLES = {
    com_preference_binding_methods: [0, 1, 2],
    com_preference_dbsc_statuses: [0, 1, 2, 3, 4],
    com_preference_statuses: [1, 2],
    com_preference_language_options: [1, 2],
    com_preference_region_options: [1, 2],
    com_preference_timezone_options: [1, 2],
    com_preference_colortheme_options: [1, 2, 3],
  }.freeze

  def change
    safety_assured do
      REFERENCE_TABLES.each_key do |table_name|
        create_table(table_name, id: :bigint, if_not_exists: true)
      end

      seed_reference_ids

      add_reference_foreign_keys
    end
  end

  private

  def seed_reference_ids
    REFERENCE_TABLES.each do |table_name, ids|
      ids.each do |id|
        execute(<<~SQL.squish)
          INSERT INTO #{table_name} (id)
          VALUES (#{connection.quote(id)})
          ON CONFLICT (id) DO NOTHING
        SQL
      end
    end
  end

  def add_reference_foreign_keys
    add_fk(:com_preferences, :com_preference_binding_methods, :binding_method_id, "fk_com_preferences_on_binding_method_id")
    add_fk(:com_preferences, :com_preference_dbsc_statuses, :dbsc_status_id, "fk_com_preferences_on_dbsc_status_id")
    add_fk(:com_preferences, :com_preference_statuses, :status_id, "fk_com_preferences_on_status_id")
    add_fk(:com_preferences, :com_preferences, :replaced_by_id, nil, on_delete: :nullify)

    add_fk(:com_preference_cookies, :com_preferences, :preference_id)
    add_fk(:com_preference_languages, :com_preferences, :preference_id)
    add_fk(:com_preference_regions, :com_preferences, :preference_id)
    add_fk(:com_preference_timezones, :com_preferences, :preference_id)
    add_fk(:com_preference_colorthemes, :com_preferences, :preference_id)

    add_fk(:com_preference_languages, :com_preference_language_options, :option_id, "fk_com_preference_languages_on_option_id")
    add_fk(:com_preference_regions, :com_preference_region_options, :option_id, "fk_com_preference_regions_on_option_id")
    add_fk(:com_preference_timezones, :com_preference_timezone_options, :option_id, "fk_com_preference_timezones_on_option_id")
    add_fk(:com_preference_colorthemes, :com_preference_colortheme_options, :option_id, "fk_com_preference_colorthemes_on_option_id")
  end

  def add_fk(from_table, to_table, column, name = nil, **options)
    return if foreign_key_exists?(from_table, to_table, column: column)

    fk_options = { column: column, validate: false }.merge(options)
    fk_options[:name] = name if name
    add_foreign_key(from_table, to_table, **fk_options)
  end
end
