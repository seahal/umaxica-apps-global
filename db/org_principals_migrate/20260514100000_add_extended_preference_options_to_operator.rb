# frozen_string_literal: true

class AddExtendedPreferenceOptionsToOperator < ActiveRecord::Migration[8.2]
  TYPES = {
    currency: "currencies",
    date_format: "date_formats",
    time_format: "time_formats",
    motion: "motions",
    density: "densities",
    items_per_page: "items_per_pages",
  }.freeze

  def change
    add_local_columns(:staff_preferences)

    create_preference_tables(:staff, :staff_preferences)
  end

  private

  def add_local_columns(table_name)
    add_column table_name, :currency, :string, null: false, default: "jpy"
    add_column table_name, :date_format, :string, null: false, default: "iso"
    add_column table_name, :time_format, :string, null: false, default: "hour_24"
    add_column table_name, :motion, :string, null: false, default: "standard"
    add_column table_name, :density, :string, null: false, default: "standard"
    add_column table_name, :items_per_page, :string, null: false, default: "20"
  end

  def create_preference_tables(prefix, parent_table)
    TYPES.each do |type, plural|
      option_table = :"#{prefix}_preference_#{type}_options"
      child_table = :"#{prefix}_preference_#{plural}"

      create_table option_table

      create_table child_table do |t|
        t.references :preference, null: false, index: { unique: true }, foreign_key: { to_table: parent_table }
        t.references :option, null: false, foreign_key: { to_table: option_table }
        t.timestamps
      end
    end
  end
end
