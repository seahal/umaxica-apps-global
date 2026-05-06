# frozen_string_literal: true

class AddIdFormatConstraintsToDocumentTables < ActiveRecord::Migration[8.2]
  def up
    tables_to_constrain.each do |table_name|
      safety_assured do
        execute(<<~SQL.squish)
          ALTER TABLE #{table_name}
          ADD CONSTRAINT #{table_name}_id_format_check
          CHECK (id::text ~ '^[A-Z0-9_]+$')
        SQL
      end
    end
  end

  def down
    tables_to_constrain.each do |table_name|
      safety_assured do
        execute(<<~SQL.squish)
          ALTER TABLE #{table_name}
          DROP CONSTRAINT IF EXISTS #{table_name}_id_format_check
        SQL
      end
    end
  end

  private

  def tables_to_constrain
    %w(
      org_document_statuses
      org_document_tag_masters
      org_document_category_masters
      com_document_statuses
      com_document_tag_masters
      com_document_category_masters
      app_document_statuses
      app_document_tag_masters
      app_document_category_masters
    )
  end
end
