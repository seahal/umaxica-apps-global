# frozen_string_literal: true

class RenameCustomerActorToVisitor < ActiveRecord::Migration[8.2]
  TABLE_RENAMES = {
    customer_preferences: :visitor_preferences,
    customer_preference_languages: :visitor_preference_languages,
    customer_preference_language_options: :visitor_preference_language_options,
    customer_preference_regions: :visitor_preference_regions,
    customer_preference_region_options: :visitor_preference_region_options,
    customer_preference_themes: :visitor_preference_themes,
    customer_preference_theme_options: :visitor_preference_theme_options,
    customer_preference_timezones: :visitor_preference_timezones,
    customer_preference_timezone_options: :visitor_preference_timezone_options,
  }.freeze

  def up
    safety_assured do
      rename_tables(TABLE_RENAMES)
      rename_column(:visitor_preferences, :customer_id, :visitor_id) if column_exists?(:visitor_preferences, :customer_id)
      rename_database_objects("customer", "visitor")
    end
  end

  def down
    safety_assured do
      rename_column(:visitor_preferences, :visitor_id, :customer_id) if column_exists?(:visitor_preferences, :visitor_id)
      rename_tables(TABLE_RENAMES.invert)
      rename_database_objects("visitor", "customer")
    end
  end

  private

  def rename_tables(renames)
    renames.each do |old_name, new_name|
      rename_table(old_name, new_name) if table_exists?(old_name) && !table_exists?(new_name)
    end
  end

  def rename_database_objects(old_fragment, new_fragment)
    connection.tables.each do |table_name|
      indexes(table_name).each do |index|
        next unless index.name.include?(old_fragment)

        new_name = index.name.gsub(old_fragment, new_fragment)
        rename_index(table_name, index.name, new_name) unless index_name_exists?(table_name, new_name)
      end
    end
  end
end
