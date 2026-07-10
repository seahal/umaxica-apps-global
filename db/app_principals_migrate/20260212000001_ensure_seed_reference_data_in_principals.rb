# frozen_string_literal: true

class EnsureSeedReferenceDataInPrincipals < ActiveRecord::Migration[8.2]
  DATA = {
    client_statuses: {
      1 => "ACTIVE",
      2 => "INACTIVE",
      3 => "PENDING",
      4 => "DELETED",
      5 => "NEYO",
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
    user_telephone_statuses: {
      1 => "UNVERIFIED",
      2 => "VERIFIED",
      3 => "SUSPENDED",
      4 => "DELETED",
      5 => "NEYO",
      6 => "UNVERIFIED_WITH_SIGN_UP",
      7 => "VERIFIED_WITH_SIGN_UP",
    },
  }.freeze

  def up
    safety_assured do
      DATA.each do |table_name, mapping|
        upsert_rows(table_name, mapping)
      end
    end
  end

  def down
    # No-op: keep shared reference data in place.
  end

  private

  def upsert_rows(table_name, mapping)
    return unless table_exists?(table_name)

    has_code = column_exists?(table_name, :code)

    mapping.each do |id, code|
      if has_code
        execute(<<~SQL.squish)
          INSERT INTO #{table_name} (id, code)
          VALUES (#{connection.quote(id)}, #{connection.quote(code)})
          ON CONFLICT (id) DO UPDATE SET code = EXCLUDED.code
        SQL
      else
        execute(<<~SQL.squish)
          INSERT INTO #{table_name} (id)
          VALUES (#{connection.quote(id)})
          ON CONFLICT (id) DO NOTHING
        SQL
      end
    end

    ensure_sequence!(table_name, mapping.keys.max)
  end

  def ensure_sequence!(table_name, max_id)
    sequence_name = select_value("SELECT pg_get_serial_sequence(#{connection.quote(table_name.to_s)}, 'id')")
    return if sequence_name.blank?

    execute("SELECT setval(#{connection.quote(sequence_name)}, #{Integer(max_id)}, true)")
  end
end
