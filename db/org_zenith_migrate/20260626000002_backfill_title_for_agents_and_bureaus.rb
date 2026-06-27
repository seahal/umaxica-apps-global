# frozen_string_literal: true

class BackfillTitleForAgentsAndBureaus < ActiveRecord::Migration[8.2]
  class BackfillAgent < ActiveRecord::Base
    self.table_name = "agents"
  end

  class BackfillBureau < ActiveRecord::Base
    self.table_name = "bureaus"
  end

  def up
    backfill(BackfillAgent, :moniker, "Account")
    backfill(BackfillBureau, :name, "Org")
  end

  def down
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
