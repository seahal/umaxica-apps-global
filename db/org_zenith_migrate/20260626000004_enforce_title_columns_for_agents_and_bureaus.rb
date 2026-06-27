# frozen_string_literal: true

class EnforceTitleColumnsForAgentsAndBureaus < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint :agents, name: "agents_title_null"
    validate_check_constraint :bureaus, name: "bureaus_title_null"
    change_column_null :agents, :title, false
    change_column_null :bureaus, :title, false
    remove_check_constraint :agents, name: "agents_title_null"
    remove_check_constraint :bureaus, name: "bureaus_title_null"
  end

  def down
    add_check_constraint :agents, "title IS NOT NULL", name: "agents_title_null", validate: false
    add_check_constraint :bureaus, "title IS NOT NULL", name: "bureaus_title_null", validate: false
    change_column_null :agents, :title, true
    change_column_null :bureaus, :title, true
  end
end
