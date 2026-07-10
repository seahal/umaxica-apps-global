# frozen_string_literal: true

class CreateVisitorPreferences < ActiveRecord::Migration[8.2]
  def change
    create_table :visitor_preference_language_options, if_not_exists: true do |t|
      t.index :id, unique: true, if_not_exists: true
    end

    create_table :visitor_preference_timezone_options, if_not_exists: true do |t|
      t.index :id, unique: true, if_not_exists: true
    end

    create_table :visitor_preference_region_options, if_not_exists: true do |t|
      t.index :id, unique: true, if_not_exists: true
    end

    create_table :visitor_preference_theme_options, if_not_exists: true do |t|
      t.index :id, unique: true, if_not_exists: true
    end

    create_table :visitor_preferences, if_not_exists: true do |t|
      t.references :visitor, null: false, foreign_key: { to_table: :visitors }, index: { unique: true }
      t.boolean :consented, null: false, default: false
      t.boolean :functional, null: false, default: false
      t.boolean :performant, null: false, default: false
      t.boolean :targetable, null: false, default: false
      t.datetime :consented_at
      t.uuid :consent_version
      t.string :language, null: false, default: "ja"
      t.string :region, null: false, default: "jp"
      t.string :timezone, null: false, default: "Asia/Tokyo"
      t.string :theme, null: false, default: "sy"
      t.string :currency, null: false, default: "jpy"
      t.string :date_format, null: false, default: "iso"
      t.string :time_format, null: false, default: "hour_24"
      t.string :motion, null: false, default: "standard"
      t.string :density, null: false, default: "standard"
      t.string :items_per_page, null: false, default: "20"
      t.string :public_id, limit: 21
      t.timestamps
    end

    add_index :visitor_preferences, :public_id, unique: true, if_not_exists: true

    create_preference_child_table(
      :visitor_preference_languages,
      :visitor_preference_language_options,
    )
    create_preference_child_table(
      :visitor_preference_timezones,
      :visitor_preference_timezone_options,
    )
    create_preference_child_table(
      :visitor_preference_regions,
      :visitor_preference_region_options,
    )
    create_preference_child_table(
      :visitor_preference_themes,
      :visitor_preference_theme_options,
    )
  end

  private

  def create_preference_child_table(table_name, option_table)
    create_table table_name, if_not_exists: true do |t|
      t.references :preference, null: false, foreign_key: { to_table: :visitor_preferences }, index: { unique: true }
      t.references :option, null: false, foreign_key: { to_table: option_table }
      t.timestamps
    end
  end
end
