# frozen_string_literal: true

class UpdateOperatorPreferenceDefaults < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      change_column_default :operator_preferences, :time_format, from: "hour_24", to: "24"
      change_column_default :operator_preferences, :page_size, from: "20", to: "infinity"
    end
  end

  def down
    safety_assured do
      change_column_default :operator_preferences, :time_format, from: "24", to: "hour_24"
      change_column_default :operator_preferences, :page_size, from: "infinity", to: "20"
    end
  end
end
