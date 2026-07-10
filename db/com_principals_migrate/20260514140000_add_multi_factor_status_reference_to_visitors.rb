# frozen_string_literal: true

class AddMultiFactorStatusReferenceToVisitors < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  class ReferenceRow < ActiveRecord::Base
    self.abstract_class = true
  end

  IDS = [0, 1, 5].freeze

  def up
    create_table(:visitor_multi_factor_statuses, id: :bigint) unless table_exists?(:visitor_multi_factor_statuses)
    seed_reference_rows(:visitor_multi_factor_statuses)

    return if column_exists?(:visitors, :multi_factor_status_id)

    add_reference(
      :visitors,
      :multi_factor_status,
      type: :bigint,
      null: false,
      default: 5,
      foreign_key: { to_table: :visitor_multi_factor_statuses, validate: false },
      index: { algorithm: :concurrently },
    )
  end

  def down
    if column_exists?(:visitors, :multi_factor_status_id)
      remove_reference(:visitors, :multi_factor_status, foreign_key: { to_table: :visitor_multi_factor_statuses })
    end
    drop_table(:visitor_multi_factor_statuses) if table_exists?(:visitor_multi_factor_statuses)
  end

  private

  def seed_reference_rows(table_name)
    ReferenceRow.establish_connection(connection.pool.db_config)
    ReferenceRow.table_name = table_name.to_s
    ReferenceRow.primary_key = "id"

    missing_ids = IDS - ReferenceRow.where(id: IDS).pluck(:id)
    return if missing_ids.blank?

    ReferenceRow.insert_all(missing_ids.map { |id| { id: id } })
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
