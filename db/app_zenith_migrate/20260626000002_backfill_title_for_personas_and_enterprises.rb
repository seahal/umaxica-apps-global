# frozen_string_literal: true

class BackfillTitleForPersonasAndEnterprises < ActiveRecord::Migration[8.2]
  class BackfillPersona < ActiveRecord::Base
    self.table_name = "personas"
  end

  class BackfillEnterprise < ActiveRecord::Base
    self.table_name = "enterprises"
  end

  def up
    backfill(BackfillPersona, :moniker, "Account")
    backfill(BackfillEnterprise, :name, "Org")
  end

  def down
    # Intentionally no-op. The column remains in place and backfilled data cannot be reconstructed.
  end

  private

  def backfill(model, source_column, fallback)
    model.reset_column_information
    model.find_each do |record|
      record.update_columns(title: normalized_title(record.public_send(source_column), fallback))
    end
  end

  def normalized_title(value, fallback)
    title = value.to_s.gsub(/[^A-Za-z0-9]/, "").first(10)
    title.present? ? title : fallback
  end
end
