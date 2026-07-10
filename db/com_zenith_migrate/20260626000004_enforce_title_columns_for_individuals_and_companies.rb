# frozen_string_literal: true

class EnforceTitleColumnsForIndividualsAndCompanies < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint :individuals, name: "individuals_title_null"
    validate_check_constraint :companies, name: "companies_title_null"
    change_column_null :individuals, :title, false
    change_column_null :companies, :title, false
    remove_check_constraint :individuals, name: "individuals_title_null"
    remove_check_constraint :companies, name: "companies_title_null"
  end

  def down
    add_check_constraint :individuals, "title IS NOT NULL", name: "individuals_title_null", validate: false
    add_check_constraint :companies, "title IS NOT NULL", name: "companies_title_null", validate: false
    change_column_null :individuals, :title, true
    change_column_null :companies, :title, true
  end
end
