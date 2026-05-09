class AddLapsesAtAndConsolidateRetentionOnPrincipals < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      add_column :users, :lapses_at, :datetime, null: false, default: -> { "'infinity'" }
      rename_column :users, :deletable_at, :purge_at
      
      reversible do |dir|
        dir.up do
          execute("UPDATE users SET shreddable_at = LEAST(purge_at, shreddable_at) WHERE shreddable_at IS NOT NULL;") if column_exists?(:users, :shreddable_at)
          execute("UPDATE users SET scheduled_purge_at = LEAST(purge_at, scheduled_purge_at) WHERE scheduled_purge_at IS NOT NULL;") if column_exists?(:users, :scheduled_purge_at)
        end
      end

      remove_column :users, :shreddable_at, :datetime, if_exists: true
      remove_column :users, :scheduled_purge_at, :datetime, if_exists: true
      
      reversible do |dir|
        dir.up do
          execute("ALTER TABLE users ADD CONSTRAINT chk_users_retention_order CHECK (lapses_at <= purge_at) NOT VALID;")
          execute("ALTER TABLE users VALIDATE CONSTRAINT chk_users_retention_order;")
        end
        dir.down do
          execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS chk_users_retention_order;")
        end
      end
    end
  end
end
