# frozen_string_literal: true

class CreateStaffPreferencesInOperator < ActiveRecord::Migration[8.2]
  def change # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    safety_assured do
      # Staff preference option tables
      create_table(:staff_preference_language_options)
      create_table(:staff_preference_timezone_options)
      create_table(:staff_preference_region_options)
      create_table(:staff_preference_colortheme_options)

      # Staff preferences
      create_table(:staff_preferences) do |t|
        t.bigint(:staff_id, null: false)
        t.boolean(:consented, default: false, null: false)
        t.boolean(:functional, default: false, null: false)
        t.boolean(:performant, default: false, null: false)
        t.boolean(:targetable, default: false, null: false)
        t.datetime(:consented_at)
        t.uuid(:consent_version)
        t.string(:language, default: "ja", null: false)
        t.string(:region, default: "jp", null: false)
        t.string(:timezone, default: "Asia/Tokyo", null: false)
        t.string(:theme, default: "sy", null: false)
        t.timestamps
      end

      add_index(:staff_preferences, :staff_id, unique: true)
      add_foreign_key(:staff_preferences, :staffs, column: :staff_id)

      # Staff preference child records
      create_table(:staff_preference_languages) do |t|
        t.bigint(:preference_id, null: false)
        t.bigint(:option_id, null: false)
        t.timestamps
      end

      add_index(:staff_preference_languages, :preference_id, unique: true)
      add_index(:staff_preference_languages, :option_id)
      add_foreign_key(
        :staff_preference_languages, :staff_preferences,
        column: :preference_id,
        name: "fk_staff_preference_languages_on_preference_id",
      )
      add_foreign_key(
        :staff_preference_languages, :staff_preference_language_options,
        column: :option_id,
        name: "fk_staff_preference_languages_on_option_id",
      )

      create_table(:staff_preference_timezones) do |t|
        t.bigint(:preference_id, null: false)
        t.bigint(:option_id, null: false)
        t.timestamps
      end

      add_index(:staff_preference_timezones, :preference_id, unique: true)
      add_index(:staff_preference_timezones, :option_id)
      add_foreign_key(
        :staff_preference_timezones, :staff_preferences,
        column: :preference_id,
        name: "fk_staff_preference_timezones_on_preference_id",
      )
      add_foreign_key(
        :staff_preference_timezones, :staff_preference_timezone_options,
        column: :option_id,
        name: "fk_staff_preference_timezones_on_option_id",
      )

      create_table(:staff_preference_regions) do |t|
        t.bigint(:preference_id, null: false)
        t.bigint(:option_id, null: false)
        t.timestamps
      end

      add_index(:staff_preference_regions, :preference_id, unique: true)
      add_index(:staff_preference_regions, :option_id)
      add_foreign_key(
        :staff_preference_regions, :staff_preferences,
        column: :preference_id,
        name: "fk_staff_preference_regions_on_preference_id",
      )
      add_foreign_key(
        :staff_preference_regions, :staff_preference_region_options,
        column: :option_id,
        name: "fk_staff_preference_regions_on_option_id",
      )

      create_table(:staff_preference_colorthemes) do |t|
        t.bigint(:preference_id, null: false)
        t.bigint(:option_id, null: false)
        t.timestamps
      end

      add_index(:staff_preference_colorthemes, :preference_id, unique: true)
      add_index(:staff_preference_colorthemes, :option_id)
      add_foreign_key(
        :staff_preference_colorthemes, :staff_preferences,
        column: :preference_id,
        name: "fk_staff_preference_colorthemes_on_preference_id",
      )
      add_foreign_key(
        :staff_preference_colorthemes, :staff_preference_colortheme_options,
        column: :option_id,
        name: "fk_staff_preference_colorthemes_on_option_id",
      )
    end

    # Seed default values for options
    up_only do
      safety_assured do
        # Manual seed using raw SQL to avoid model/relation resolution issues during migration
        execute("INSERT INTO staff_preference_language_options (id) VALUES (1), (2) ON CONFLICT (id) DO NOTHING")
        execute("INSERT INTO staff_preference_timezone_options (id) VALUES (1), (2) ON CONFLICT (id) DO NOTHING")
        execute("INSERT INTO staff_preference_region_options (id) VALUES (0), (1), (2) ON CONFLICT (id) DO NOTHING")
        execute("INSERT INTO staff_preference_colortheme_options (id) VALUES (0), (1), (2), (3) ON CONFLICT (id) DO NOTHING")
      end
    end
  end
end
