# frozen_string_literal: true

class CreateCustomerPreferencesInSetting < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      create_table(:customer_preferences) do |t|
        t.uuid :consent_version
        t.boolean :consented, null: false, default: false
        t.datetime :consented_at
        t.boolean :functional, null: false, default: false
        t.string :language, null: false, default: "ja"
        t.boolean :performant, null: false, default: false
        t.string :region, null: false, default: "jp"
        t.boolean :targetable, null: false, default: false
        t.string :theme, null: false, default: "sy"
        t.string :timezone, null: false, default: "Asia/Tokyo"
        t.bigint :customer_id, null: false
        t.timestamps
      end

      # Add unique index on customer_id (application-level FK to guest.customers)
      add_index :customer_preferences, :customer_id, unique: true

      create_table(:customer_preference_language_options, id: :bigint)
      create_table(:customer_preference_timezone_options, id: :bigint)
      create_table(:customer_preference_region_options, id: :bigint)
      create_table(:customer_preference_colortheme_options, id: :bigint)

      create_table(:customer_preference_languages) do |t|
        t.bigint :preference_id, null: false
        t.bigint :option_id, null: false
        t.timestamps
      end

      add_index :customer_preference_languages, :preference_id, unique: true
      add_index :customer_preference_languages, :option_id

      create_table(:customer_preference_timezones) do |t|
        t.bigint :preference_id, null: false
        t.bigint :option_id, null: false
        t.timestamps
      end

      add_index :customer_preference_timezones, :preference_id, unique: true
      add_index :customer_preference_timezones, :option_id

      create_table(:customer_preference_regions) do |t|
        t.bigint :preference_id, null: false
        t.bigint :option_id, null: false
        t.timestamps
      end

      add_index :customer_preference_regions, :preference_id, unique: true
      add_index :customer_preference_regions, :option_id

      create_table(:customer_preference_colorthemes) do |t|
        t.bigint :preference_id, null: false
        t.bigint :option_id, null: false
        t.timestamps
      end

      add_index :customer_preference_colorthemes, :preference_id, unique: true
      add_index :customer_preference_colorthemes, :option_id

      seed_reference_ids(:customer_preference_language_options, [0, 1, 2])
      seed_reference_ids(:customer_preference_timezone_options, [1, 2])
      seed_reference_ids(:customer_preference_region_options, [0, 1, 2])
      seed_reference_ids(:customer_preference_colortheme_options, [0, 1, 2, 3])
    end
  end

  private

  def seed_reference_ids(table_name, ids)
    ids.each do |id|
      execute(<<~SQL.squish)
        INSERT INTO #{table_name} (id)
        VALUES (#{connection.quote(id)})
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end
end
