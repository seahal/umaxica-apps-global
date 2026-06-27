# frozen_string_literal: true

class AddTitleToIndividualsAndCompanies < ActiveRecord::Migration[8.2]
  def change
    add_column :individuals, :title, :string
    add_column :companies, :title, :string
  end
end
