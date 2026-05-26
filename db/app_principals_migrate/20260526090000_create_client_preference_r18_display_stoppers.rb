# frozen_string_literal: true

class CreateClientPreferenceR18DisplayStoppers < ActiveRecord::Migration[8.2]
  def change
    create_table :client_preference_r18_display_stopper_options do |t|
    end

    create_table :client_preference_r18_display_stoppers do |t|
      t.references :preference, null: false, foreign_key: { to_table: :client_preferences }, index: { unique: true }
      t.references :option, null: false, foreign_key: { to_table: :client_preference_r18_display_stopper_options }
      t.timestamps
    end
  end
end
