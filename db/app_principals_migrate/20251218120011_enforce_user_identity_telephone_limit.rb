# frozen_string_literal: true

class EnforceUserIdentityTelephoneLimit < ActiveRecord::Migration[8.2]
  FUNCTION_NAME = "check_user_identity_telephones_limit"
  TRIGGER_NAME = "enforce_user_identity_telephones_limit"
  LIMIT = 4

  def up
    execute(<<~SQL.squish)
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}()
      RETURNS trigger AS $$
      DECLARE
        telephones_count integer;
      BEGIN
        IF NEW.user_id IS NULL THEN
          RETURN NEW;
        END IF;
        SELECT COUNT(*) INTO telephones_count FROM user_identity_telephones WHERE user_id = NEW.user_id;
        IF telephones_count >= #{LIMIT} THEN
          RAISE EXCEPTION 'user_identity_telephones limit (#{LIMIT}) exceeded for user %', NEW.user_id
            USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    execute(<<~SQL.squish)
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON user_identity_telephones;
    SQL

    execute(<<~SQL.squish)
      DROP FUNCTION IF EXISTS #{FUNCTION_NAME}();
    SQL
  end
end
