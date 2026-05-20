# frozen_string_literal: true

class AddPublicIdToStaffEmails < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column(:staff_emails, :public_id, :string, limit: 21, if_not_exists: true)

    enable_extension('pgcrypto') unless extension_enabled?('pgcrypto')

    reversible do |dir|
      dir.up do
        safety_assured do
          execute(<<~SQL.squish)
            UPDATE staff_emails
            SET public_id = REPLACE(REPLACE(SUBSTRING(ENCODE(gen_random_bytes(16), 'base64') FROM 1 FOR 21), '+', '-'), '/', '_')
            WHERE public_id IS NULL
          SQL
        end
      end
    end

    safety_assured { change_column_null(:staff_emails, :public_id, false) }
    add_index(:staff_emails, :public_id, unique: true, algorithm: :concurrently, if_not_exists: true)
  end
end
