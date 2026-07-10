# frozen_string_literal: true

class ValidateTitleColumnsForAgentsAndBureaus < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint :agents, "title IS NOT NULL", name: "agents_title_null", validate: false
    add_check_constraint :bureaus, "title IS NOT NULL", name: "bureaus_title_null", validate: false
  end
end
