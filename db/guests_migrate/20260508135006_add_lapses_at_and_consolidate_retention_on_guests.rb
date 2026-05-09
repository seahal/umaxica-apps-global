class AddLapsesAtAndConsolidateRetentionOnGuests < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :customers, :lapses_at, :datetime, null: false, default: -> { "'infinity'" }
      rename_column :customers, :deletable_at, :purge_at
      
      reversible do |dir|
        dir.up do
          execute("UPDATE customers SET shreddable_at = LEAST(purge_at, shreddable_at) WHERE shreddable_at IS NOT NULL;") if column_exists?(:customers, :shreddable_at)
          execute("UPDATE customers SET scheduled_purge_at = LEAST(purge_at, scheduled_purge_at) WHERE scheduled_purge_at IS NOT NULL;") if column_exists?(:customers, :scheduled_purge_at)
        end
      end

      remove_column :customers, :shreddable_at, :datetime, if_exists: true
      remove_column :customers, :scheduled_purge_at, :datetime, if_exists: true
      
      reversible do |dir|
        dir.up do
          execute("ALTER TABLE customers ADD CONSTRAINT chk_customers_retention_order CHECK (lapses_at <= purge_at) NOT VALID;")
          execute("ALTER TABLE customers VALIDATE CONSTRAINT chk_customers_retention_order;")
        end
        dir.down do
          execute("ALTER TABLE customers DROP CONSTRAINT IF EXISTS chk_customers_retention_order;")
        end
      end
    end
  end
end
