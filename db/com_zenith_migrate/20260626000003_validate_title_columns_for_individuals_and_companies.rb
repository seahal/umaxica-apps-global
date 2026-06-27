# frozen_string_literal: true

class ValidateTitleColumnsForIndividualsAndCompanies < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint :individuals, "title IS NOT NULL", name: "individuals_title_null", validate: false
    add_check_constraint :companies, "title IS NOT NULL", name: "companies_title_null", validate: false
  end
end
