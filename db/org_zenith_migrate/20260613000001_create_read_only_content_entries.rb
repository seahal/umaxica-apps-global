# typed: false
# frozen_string_literal: true

class CreateReadOnlyContentEntries < ActiveRecord::Migration[8.0]
  TABLES = %i(docs_content_entries news_content_entries help_content_entries).freeze

  def change
    TABLES.each do |table_name|
      create_table table_name do |t|
        t.string :slug, null: false
        t.string :locale, null: false
        t.string :title, null: false
        t.text :summary
        t.text :body, null: false
        t.string :status, null: false, default: "draft"
        t.datetime :published_at
        t.timestamps
      end

      add_index table_name, %i(locale slug), unique: true
      add_index table_name, %i(status published_at)
    end
  end
end
