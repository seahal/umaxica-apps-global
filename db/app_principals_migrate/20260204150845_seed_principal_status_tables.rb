# frozen_string_literal: true

class SeedPrincipalStatusTables < ActiveRecord::Migration[8.2]
  def up
    target_tables = {
      user_statuses: {
        1 => "ACTIVE",
        2 => "INACTIVE",
        3 => "PENDING",
        4 => "DELETED",
        5 => "WITHDRAWN",
        6 => "PENDING_DELETION",
        7 => "PRE_WITHDRAWAL_CONDITION",
        8 => "WITHDRAWAL_COMPLETED",
        9 => "UNVERIFIED_WITH_SIGN_UP",
        10 => "VERIFIED_WITH_SIGN_UP",
        11 => "NEYO",
        12 => "GHOST",
        13 => "NONE",
      },
      user_email_statuses: {
        1 => "UNVERIFIED",
        2 => "VERIFIED",
        3 => "SUSPENDED",
        4 => "DELETED",
        5 => "NEYO",
        6 => "UNVERIFIED_WITH_SIGN_UP",
        7 => "VERIFIED_WITH_SIGN_UP",
      },
      client_statuses: {
        1 => "ACTIVE",
        2 => "INACTIVE",
        3 => "PENDING",
        4 => "DELETED",
        5 => "NEYO",
      },
      user_telephone_statuses: {
        1 => "UNVERIFIED",
        2 => "VERIFIED",
        3 => "SUSPENDED",
        4 => "DELETED",
        5 => "NEYO",
      },
      user_one_time_password_statuses: {
        1 => "ACTIVE",
        2 => "INACTIVE",
        3 => "REVOKED",
        4 => "DELETED",
        5 => "NEYO",
      },
      user_passkey_statuses: {
        1 => "ACTIVE",
        2 => "DISABLED",
        3 => "REVOKED",
        4 => "DELETED",
        5 => "NEYO",
      },
      user_secret_kinds: {
        1 => "LOGIN",
        2 => "TOTP",
        3 => "RECOVERY",
        4 => "API",
      },
      user_secret_statuses: {
        1 => "ACTIVE",
        2 => "EXPIRED",
        3 => "REVOKED",
        4 => "USED",
        5 => "DELETED",
        6 => "NEYO",
      },
      user_social_apple_statuses: {
        1 => "ACTIVE",
        2 => "INACTIVE",
        3 => "PENDING",
        4 => "DELETED",
        5 => "REVOKED",
        6 => "NEYO",
      },
      user_social_google_statuses: {
        1 => "ACTIVE",
        2 => "INACTIVE",
        3 => "PENDING",
        4 => "DELETED",
        5 => "REVOKED",
        6 => "NEYO",
      },
    }

    safety_assured do
      target_tables.each do |table_name, mapping|
        # Insert fixed IDs (skip if already exists)
        mapping.each do |id, _name|
          execute(<<~SQL.squish)
            INSERT INTO #{table_name} (id)
            VALUES (#{id})
            ON CONFLICT (id) DO NOTHING
          SQL
        end

        # Update sequence to ensure next auto-generated ID doesn't conflict
        max_id = mapping.keys.max
        execute("SELECT setval(pg_get_serial_sequence('#{table_name}', 'id'), #{max_id}, true)")
      end
    end
  end

  def down
    # No-op: keep seeded status data in place
    # Removing status records would break foreign key constraints
  end
end
