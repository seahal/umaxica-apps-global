# frozen_string_literal: true

class EnforceUserIdentityOneTimePasswordLimit < ActiveRecord::Migration[8.2]
  FUNCTION_NAME = "check_user_identity_totp_limit"
  TRIGGER_NAME = "enforce_user_identity_totp_limit"
  LIMIT = 2

  def up
    execute(<<~SQL.squish)
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}()
      RETURNS trigger AS $$
      DECLARE
        totp_count integer;
      BEGIN
        SELECT COUNT(*) INTO totp_count FROM user_identity_one_time_passwords WHERE user_id = NEW.user_id;
        IF totp_count >= #{LIMIT} THEN
          RAISE EXCEPTION 'user_identity_one_time_passwords limit (#{LIMIT}) exceeded for user %', NEW.user_id
            USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    execute(<<~SQL.squish)
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON user_identity_one_time_passwords;
    SQL

    execute(<<~SQL.squish)
      DROP FUNCTION IF EXISTS #{FUNCTION_NAME}();
    SQL
  end
end
