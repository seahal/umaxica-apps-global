# frozen_string_literal: true

class EnforceStaffIdentityPasskeyLimit < ActiveRecord::Migration[8.2]
  FUNCTION_NAME = "check_staff_identity_passkeys_limit"
  TRIGGER_NAME = "enforce_staff_identity_passkeys_limit"
  LIMIT = 4

  def up
    return unless table_exists?(:staff_identity_passkeys)

    execute(<<~SQL.squish)
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}()
      RETURNS trigger AS $$
      DECLARE
        passkeys_count integer;
      BEGIN
        SELECT COUNT(*) INTO passkeys_count FROM staff_identity_passkeys WHERE staff_id = NEW.staff_id;
        IF passkeys_count >= #{LIMIT} THEN
          RAISE EXCEPTION 'staff_identity_passkeys limit (#{LIMIT}) exceeded for staff %', NEW.staff_id
            USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    return unless table_exists?(:staff_identity_passkeys)

    execute(<<~SQL.squish)
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON staff_identity_passkeys;
    SQL

    execute(<<~SQL.squish)
      DROP FUNCTION IF EXISTS #{FUNCTION_NAME}();
    SQL
  end
end
