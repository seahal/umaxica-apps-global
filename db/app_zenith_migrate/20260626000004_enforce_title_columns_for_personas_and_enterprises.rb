# frozen_string_literal: true

class EnforceTitleColumnsForPersonasAndEnterprises < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint :personas, name: "personas_title_null"
    validate_check_constraint :enterprises, name: "enterprises_title_null"
    change_column_null :personas, :title, false
    change_column_null :enterprises, :title, false
    remove_check_constraint :personas, name: "personas_title_null"
    remove_check_constraint :enterprises, name: "enterprises_title_null"
  end

  def down
    add_check_constraint :personas, "title IS NOT NULL", name: "personas_title_null", validate: false
    add_check_constraint :enterprises, "title IS NOT NULL", name: "enterprises_title_null", validate: false
    change_column_null :personas, :title, true
    change_column_null :enterprises, :title, true
  end
end
