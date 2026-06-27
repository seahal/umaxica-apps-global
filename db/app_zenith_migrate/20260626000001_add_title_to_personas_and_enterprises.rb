# frozen_string_literal: true

class AddTitleToPersonasAndEnterprises < ActiveRecord::Migration[8.2]
  def change
    add_column :personas, :title, :string
    add_column :enterprises, :title, :string
  end
end
