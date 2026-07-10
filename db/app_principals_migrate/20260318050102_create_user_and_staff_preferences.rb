# frozen_string_literal: true

class CreateUserAndStaffPreferences < ActiveRecord::Migration[8.1]
  def change # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    safety_assured do
      # User preference option tables
      create_table(:user_preference_language_options)

      create_table(:user_preference_timezone_options)

      create_table(:user_preference_region_options)

      create_table(:user_preference_colortheme_options)

      # User preferences
      create_table(:user_preferences) do |t|
        t.bigint(:user_id, null: false)
        t.boolean(:consented, default: false, null: false)
        t.boolean(:functional, default: false, null: false)
        t.boolean(:performant, default: false, null: false)
        t.boolean(:targetable, default: false, null: false)
        t.datetime(:consented_at)
        t.uuid(:consent_version)
        t.timestamps
      end

      add_index(:user_preferences, :user_id, unique: true)

      # User preference child records
      create_table(:user_preference_languages) do |t|
        t.bigint(:preference_id, null: false)
        t.bigint(:option_id, null: false)
        t.timestamps
      end

      add_index(:user_preference_languages, :preference_id, unique: true)
      add_index(:user_preference_languages, :option_id)
      add_foreign_key(
        :user_preference_languages, :user_preferences,
        column: :preference_id,
        name: "fk_user_preference_languages_on_preference_id",
      )
      add_foreign_key(
        :user_preference_languages, :user_preference_language_options,
        column: :option_id,
        name: "fk_user_preference_languages_on_option_id",
      )

      create_table(:user_preference_timezones) do |t|
        t.bigint(:preference_id, null: false)
        t.bigint(:option_id, null: false)
        t.timestamps
      end

      add_index(:user_preference_timezones, :preference_id, unique: true)
      add_index(:user_preference_timezones, :option_id)
      add_foreign_key(
        :user_preference_timezones, :user_preferences,
        column: :preference_id,
        name: "fk_user_preference_timezones_on_preference_id",
      )
      add_foreign_key(
        :user_preference_timezones, :user_preference_timezone_options,
        column: :option_id,
        name: "fk_user_preference_timezones_on_option_id",
      )

      create_table(:user_preference_regions) do |t|
        t.bigint(:preference_id, null: false)
        t.bigint(:option_id, null: false)
        t.timestamps
      end

      add_index(:user_preference_regions, :preference_id, unique: true)
      add_index(:user_preference_regions, :option_id)
      add_foreign_key(
        :user_preference_regions, :user_preferences,
        column: :preference_id,
        name: "fk_user_preference_regions_on_preference_id",
      )
      add_foreign_key(
        :user_preference_regions, :user_preference_region_options,
        column: :option_id,
        name: "fk_user_preference_regions_on_option_id",
      )

      create_table(:user_preference_colorthemes) do |t|
        t.bigint(:preference_id, null: false)
        t.bigint(:option_id, null: false)
        t.timestamps
      end

      add_index(:user_preference_colorthemes, :preference_id, unique: true)
      add_index(:user_preference_colorthemes, :option_id)
      add_foreign_key(
        :user_preference_colorthemes, :user_preferences,
        column: :preference_id,
        name: "fk_user_preference_colorthemes_on_preference_id",
      )
      add_foreign_key(
        :user_preference_colorthemes, :user_preference_colortheme_options,
        column: :option_id,
        name: "fk_user_preference_colorthemes_on_option_id",
      )
    end
  end
end
