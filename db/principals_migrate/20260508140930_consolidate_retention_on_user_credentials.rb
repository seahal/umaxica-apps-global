class ConsolidateRetentionOnUserCredentials < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
      ["user_tokens", "user_verifications", "user_authorization_codes", "user_reauth_sessions", "user_secrets"].each do |t|
        if table_exists?(t)
          add_column t, :lapses_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(t, :lapses_at)
          rename_column t, :deletable_at, :purge_at if column_exists?(t, :deletable_at)
          
          reversible do |dir|
            dir.up do
              execute("UPDATE #{t} SET lapses_at = LEAST(lapses_at, refresh_expires_at) WHERE refresh_expires_at IS NOT NULL;") if column_exists?(t, :refresh_expires_at)
              execute("UPDATE #{t} SET lapses_at = LEAST(lapses_at, revoked_at) WHERE revoked_at IS NOT NULL;") if column_exists?(t, :revoked_at)
              execute("UPDATE #{t} SET lapses_at = LEAST(lapses_at, expires_at) WHERE expires_at IS NOT NULL;") if column_exists?(t, :expires_at)
            end
          end
          
          remove_column t, :refresh_expires_at, :datetime, if_exists: true
          remove_column t, :revoked_at, :datetime, if_exists: true
          remove_column t, :expired_at, :datetime, if_exists: true
          remove_column t, :expires_at, :datetime, if_exists: true
        end
      end
    end
  end
end
