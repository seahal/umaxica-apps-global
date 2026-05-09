class RenameExpiresAtToPurgeAtAndAddLapsesAtOnChronicle < ActiveRecord::Migration[8.0]
  def change
    safety_assured do
    tables = %w[app_contact_chronicles com_contact_chronicles org_contact_chronicles app_preference_chronicles com_preference_chronicles org_preference_chronicles staff_chronicles user_chronicles]
    
    tables.each do |t|
      if table_exists?(t)
        add_column t, :lapses_at, :datetime, null: false, default: -> { "'infinity'" } unless column_exists?(t, :lapses_at)
        rename_column t, :expires_at, :purge_at if column_exists?(t, :expires_at)
      end
    end
    end
  end
end
