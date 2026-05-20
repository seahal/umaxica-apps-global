# frozen_string_literal: true

class EnforceStaffIdentityEmailLimit < ActiveRecord::Migration[8.2]
  FUNCTION_NAME = "check_staff_identity_emails_limit"
  TRIGGER_NAME = "enforce_staff_identity_emails_limit"
  LIMIT = 4

  def up
    return unless table_exists?(:staff_identity_emails)

    execute(<<~SQL.squish)
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}()
      RETURNS trigger AS $$
      DECLARE
        emails_count integer;
      BEGIN
        IF NEW.staff_id IS NULL THEN
          RETURN NEW;
        END IF;
        SELECT COUNT(*) INTO emails_count FROM staff_identity_emails WHERE staff_id = NEW.staff_id;
        IF emails_count >= #{LIMIT} THEN
          RAISE EXCEPTION 'staff_identity_emails limit (#{LIMIT}) exceeded for staff %', NEW.staff_id
            USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    return unless table_exists?(:staff_identity_emails)

    execute(<<~SQL.squish)
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON staff_identity_emails;
    SQL

    execute(<<~SQL.squish)
      DROP FUNCTION IF EXISTS #{FUNCTION_NAME}();
    SQL
  end
end
