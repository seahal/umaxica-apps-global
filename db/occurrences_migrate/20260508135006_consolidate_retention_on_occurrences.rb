class ConsolidateRetentionOnOccurrences < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
    tables = %w[area_occurrences user_occurrences staff_occurrences zip_occurrences domain_occurrences ip_occurrences email_occurrences jwt_occurrences telephone_occurrences]
    tables.each do |t|
      if table_exists?(t)
        add_column t, :lapses_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(t, :lapses_at)
        rename_column t, :deletable_at, :purge_at if column_exists?(t, :deletable_at)
        
        reversible do |dir|
          dir.up do
            execute("UPDATE #{t} SET lapses_at = LEAST(lapses_at, revoked_at) WHERE revoked_at IS NOT NULL;") if column_exists?(t, :revoked_at)
          end
        end
        remove_column t, :revoked_at, :datetime, if_exists: true
      end
    end
    end
  end
end
