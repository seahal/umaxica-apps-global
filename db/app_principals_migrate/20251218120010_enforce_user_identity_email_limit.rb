# frozen_string_literal: true

class EnforceUserIdentityEmailLimit < ActiveRecord::Migration[8.2]
  FUNCTION_NAME = "check_user_identity_emails_limit"
  TRIGGER_NAME = "enforce_user_identity_emails_limit"
  LIMIT = 4

  def up
    execute(<<~SQL.squish)
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}()
      RETURNS trigger AS $$
      DECLARE
        emails_count integer;
      BEGIN
        IF NEW.user_id IS NULL THEN
          RETURN NEW;
        END IF;
        SELECT COUNT(*) INTO emails_count FROM user_identity_emails WHERE user_id = NEW.user_id;
        IF emails_count >= #{LIMIT} THEN
          RAISE EXCEPTION 'user_identity_emails limit (#{LIMIT}) exceeded for user %', NEW.user_id
            USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    execute(<<~SQL.squish)
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON user_identity_emails;
    SQL

    execute(<<~SQL.squish)
      DROP FUNCTION IF EXISTS #{FUNCTION_NAME}();
    SQL
  end
end
