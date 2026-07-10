# frozen_string_literal: true

class AddExtendedPreferenceOptionsToVisitor < ActiveRecord::Migration[8.2]
  TYPES = {
    currency: "currencies",
    date_format: "date_formats",
    time_format: "time_formats",
    motion: "motions",
    density: "densities",
    items_per_page: "items_per_pages",
  }.freeze

  def change
    create_preference_tables(:visitor, :visitor_preferences)
  end

  private

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
