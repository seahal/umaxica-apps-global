# typed: false
# frozen_string_literal: true

class AddPreferenceColumnsToUserAndStaffPreferences < ActiveRecord::Migration[8.2]
  def change
    # Add preference columns to user_preferences
    add_column(:user_preferences, :language, :string, default: "ja", null: false)
    add_column(:user_preferences, :region, :string, default: "jp", null: false)
    add_column(:user_preferences, :timezone, :string, default: "Asia/Tokyo", null: false)
    add_column(:user_preferences, :theme, :string, default: "sy", null: false)
  end
end
