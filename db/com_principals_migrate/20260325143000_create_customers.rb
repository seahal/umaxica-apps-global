# frozen_string_literal: true

class CreateCustomers < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      create_table(:customer_statuses, id: :bigint)
      create_table(:customer_visibilities, id: :bigint)

      create_table(:customers) do |t|
        t.datetime :deactivated_at
        t.datetime :deletable_at, null: false, default: -> { "'infinity'" }
        t.datetime :created_at, null: false
        t.integer :lock_version, default: 0, null: false
        t.boolean :multi_factor_enabled, default: false, null: false
        t.string :public_id, null: false, default: ""
        t.bigint :status_id, default: 2, null: false
        t.bigint :visibility_id, default: 1, null: false
        t.datetime :shreddable_at, null: false, default: -> { "'infinity'" }
        t.datetime :updated_at, null: false
        t.datetime :withdrawn_at, default: -> { "'+infinity'::timestamp" }

        t.index :deactivated_at, name: "index_customers_on_deactivated_at", where: "deactivated_at IS NOT NULL"
        t.index :deletable_at, name: "index_customers_on_deletable_at"
        t.index :public_id, name: "index_customers_on_public_id", unique: true
        t.index :shreddable_at, name: "index_customers_on_shreddable_at"
        t.index :status_id, name: "index_customers_on_status_id"
        t.index :visibility_id, name: "index_customers_on_visibility_id"
        t.index :withdrawn_at, name: "index_customers_on_withdrawn_at", where: "withdrawn_at IS NOT NULL"
      end

      add_foreign_key :customers, :customer_statuses, column: :status_id, validate: false
      add_foreign_key :customers, :customer_visibilities, column: :visibility_id, validate: false

      seed_reference_ids(:customer_statuses, [1, 2, 3])
      seed_reference_ids(:customer_visibilities, [0, 1, 2, 3])
    end
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
