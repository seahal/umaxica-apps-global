# frozen_string_literal: true

class AddMultiFactorReferenceToStaffs < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  IDS = [0, 1, 5, 9].freeze

  def up
    create_table(:staff_multi_factors, id: :bigint) unless table_exists?(:staff_multi_factors)
    seed_reference_rows(:staff_multi_factors)

    unless column_exists?(:staffs, :multi_factor_id)
      add_reference(
        :staffs,
        :multi_factor,
        type: :bigint,
        null: false,
        default: 0,
        foreign_key: { to_table: :staff_multi_factors, validate: false },
        index: { algorithm: :concurrently },
      )
    end
  end

  def down
    if column_exists?(:staffs, :multi_factor_id)
      remove_reference(:staffs, :multi_factor, foreign_key: { to_table: :staff_multi_factors })
    end
    drop_table(:staff_multi_factors) if table_exists?(:staff_multi_factors)
  end

  private

  def seed_reference_rows(table_name)
    safety_assured do
      IDS.each do |id|
        execute(<<~SQL.squish)
          INSERT INTO #{table_name} (id)
          VALUES (#{connection.quote(id)})
          ON CONFLICT (id) DO NOTHING
        SQL
      end
    end
  end
end
