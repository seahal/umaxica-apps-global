# frozen_string_literal: true

class AddTitleToAgentsAndBureaus < ActiveRecord::Migration[8.2]
  def change
    add_column :agents, :title, :string
    add_column :bureaus, :title, :string
  end
end
