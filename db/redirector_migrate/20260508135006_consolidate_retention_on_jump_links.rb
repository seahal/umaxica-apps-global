class ConsolidateRetentionOnJumpLinks < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
    tables = %w[app_jump_links com_jump_links org_jump_links]
    tables.each do |t|
      if table_exists?(t)
        add_column t, :lapses_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(t, :lapses_at)
        rename_column t, :deletable_at, :purge_at if column_exists?(t, :deletable_at)
        
        reversible do |dir|
          dir.up do
            execute("UPDATE #{t} SET purge_at = 'infinity' WHERE purge_at >= '9999-01-01';")
            execute("UPDATE #{t} SET lapses_at = LEAST(lapses_at, revoked_at) WHERE revoked_at IS NOT NULL;") if column_exists?(t, :revoked_at)
          end
        end
        remove_column t, :revoked_at, :datetime, if_exists: true
      end
    end
    end
  end
end
