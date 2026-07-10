# frozen_string_literal: true

class CreateVisitorPreferenceR18DisplayStoppers < ActiveRecord::Migration[8.2]
  def change
    create_table :visitor_preference_r18_display_stopper_options do |t|
    end

    create_table :visitor_preference_r18_display_stoppers do |t|
      t.references :preference, null: false, foreign_key: { to_table: :visitor_preferences }, index: { unique: true }
      t.references :option, null: false, foreign_key: { to_table: :visitor_preference_r18_display_stopper_options }
      t.timestamps
    end
  end
end
