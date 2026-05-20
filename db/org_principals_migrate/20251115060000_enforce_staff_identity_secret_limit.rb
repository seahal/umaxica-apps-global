# frozen_string_literal: true

class EnforceStaffIdentitySecretLimit < ActiveRecord::Migration[8.2]
  FUNCTION_NAME = "check_staff_identity_secrets_limit"
  TRIGGER_NAME = "enforce_staff_identity_secrets_limit"

  def up
    # Only create trigger if staff_identity_secrets table exists
    return unless table_exists?(:staff_identity_secrets)

    execute(<<~SQL.squish)
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}()
      RETURNS trigger AS $$
      DECLARE
        secrets_count integer;
      BEGIN
        SELECT COUNT(*) INTO secrets_count FROM staff_identity_secrets WHERE staff_id = NEW.staff_id;
        IF secrets_count >= 10 THEN
          RAISE EXCEPTION 'staff_identity_secrets limit (10) exceeded for staff %', NEW.staff_id
            USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    return unless table_exists?(:staff_identity_secrets)

    execute(<<~SQL.squish)
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON staff_identity_secrets;
    SQL

    execute(<<~SQL.squish)
      DROP FUNCTION IF EXISTS #{FUNCTION_NAME}();
    SQL
  end
end
