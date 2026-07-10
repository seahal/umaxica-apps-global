# frozen_string_literal: true

class ValidateTitleColumnsForPersonasAndEnterprises < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint :personas, "title IS NOT NULL", name: "personas_title_null", validate: false
    add_check_constraint :enterprises, "title IS NOT NULL", name: "enterprises_title_null", validate: false
  end
end
