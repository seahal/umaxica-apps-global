# frozen_string_literal: true

class CreateCustomerIdentities < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      create_table(:customer_email_statuses)
      create_table(:customer_telephone_statuses)
      create_table(:customer_secret_statuses)
      create_table(:customer_secret_kinds)
      create_table(:customer_passkey_statuses)

      create_table(:customer_emails) do |t|
        t.string :address, null: false, default: ""
        t.string :address_bidx
        t.string :address_digest
        t.datetime :locked_at, null: false, default: Float::INFINITY
        t.integer :otp_attempts_count, null: false, default: 0
        t.text :otp_counter, null: false, default: ""
        t.datetime :otp_expires_at, null: false, default: -Float::INFINITY
        t.datetime :otp_last_sent_at, null: false, default: -Float::INFINITY
        t.string :otp_private_key, null: false, default: ""
        t.boolean :undeletable, null: false, default: false
        t.binary :verification_token_digest
        t.string :public_id, limit: 21, null: false
        t.references :customer, null: false, foreign_key: true
        t.references :customer_email_status, null: false, default: 1, foreign_key: true
        t.timestamps
      end
      add_index :customer_emails, "lower((address)::text)", unique: true, name: "index_customer_emails_on_lower_address"
      add_index :customer_emails, :address_bidx, unique: true, where: "(address_bidx IS NOT NULL)"
      add_index :customer_emails, :address_digest, unique: true, where: "(address_digest IS NOT NULL)"
      add_index :customer_emails, :otp_last_sent_at
      add_index :customer_emails, :public_id, unique: true

      create_table(:customer_telephones) do |t|
        t.string :number, null: false, default: ""
        t.string :number_bidx
        t.string :number_digest
        t.datetime :locked_at, null: false, default: -Float::INFINITY
        t.integer :otp_attempts_count, null: false, default: 0
        t.text :otp_counter, null: false, default: ""
        t.datetime :otp_expires_at, null: false, default: -Float::INFINITY
        t.string :otp_private_key, null: false, default: ""
        t.string :public_id, limit: 21, null: false
        t.references :customer, null: false, foreign_key: true
        t.references :customer_telephone_status, null: false, default: 1, foreign_key: true
        t.timestamps
      end
      add_index :customer_telephones, "lower((number)::text)", unique: true, name: "index_customer_telephones_on_lower_number"
      add_index :customer_telephones, :number_bidx, unique: true, where: "(number_bidx IS NOT NULL)"
      add_index :customer_telephones, :number_digest, unique: true, where: "(number_digest IS NOT NULL)"
      add_index :customer_telephones, :public_id, unique: true

      create_table(:customer_secrets) do |t|
        t.string :name, null: false, default: ""
        t.string :password_digest, null: false, default: ""
        t.datetime :expires_at, null: false, default: Float::INFINITY
        t.datetime :last_used_at
        t.integer :uses_remaining, null: false, default: 1
        t.string :public_id, limit: 21, null: false
        t.references :customer, null: false, foreign_key: true
        t.references :customer_secret_status, null: false, default: 1, foreign_key: true
        t.references :customer_secret_kind, null: false, default: 1, foreign_key: true
        t.timestamps
      end
      add_index :customer_secrets, :expires_at
      add_index :customer_secrets, :public_id, unique: true

      create_table(:customer_passkeys) do |t|
        t.string :description, null: false, default: ""
        t.uuid :external_id, null: false
        t.datetime :last_used_at
        t.text :public_key, null: false
        t.bigint :sign_count, null: false, default: 0
        t.string :public_id, limit: 21, null: false
        t.string :webauthn_id, null: false, default: ""
        t.references :customer, null: false, foreign_key: true
        t.references :status, null: false, default: 1, foreign_key: { to_table: :customer_passkey_statuses }
        t.timestamps
      end
      add_index :customer_passkeys, :public_id, unique: true
      add_index :customer_passkeys, :webauthn_id, unique: true

      seed_reference_ids(:customer_email_statuses, [1, 2, 3, 4, 5, 6, 7])
      seed_reference_ids(:customer_telephone_statuses, [1, 2, 3, 4, 5, 6, 7])
      seed_reference_ids(:customer_secret_statuses, [1, 2, 3, 4, 5, 6])
      seed_reference_ids(:customer_secret_kinds, [1, 3, 4])
      seed_reference_ids(:customer_passkey_statuses, [1, 2, 3, 4, 5])
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
