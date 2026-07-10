# frozen_string_literal: true

class SeedCustomerReferenceIds < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      seed_reference_ids(:customer_statuses, [1, 2, 3])
      seed_reference_ids(:customer_visibilities, [0, 1, 2, 3])
    end
  end

  def down
    # no-op: reference IDs are shared immutable rows
  end

  private

  def seed_reference_ids(table_name, ids)
    ids.each do |id|
      execute(<<~SQL.squish)
        INSERT INTO #{table_name} (id)
        VALUES (#{connection.quote(id)})
        ON CONFLICT (id) DO NOTHING
      SQL
    end
  end
end
