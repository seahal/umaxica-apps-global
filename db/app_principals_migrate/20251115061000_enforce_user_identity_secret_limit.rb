# frozen_string_literal: true

class EnforceUserIdentitySecretLimit < ActiveRecord::Migration[8.2]
  FUNCTION_NAME = "check_user_identity_secrets_limit"
  TRIGGER_NAME = "enforce_user_identity_secrets_limit"

  def up
    execute(<<~SQL.squish)
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}()
      RETURNS trigger AS $$
      DECLARE
        secrets_count integer;
      BEGIN
        SELECT COUNT(*) INTO secrets_count FROM user_identity_secrets WHERE user_id = NEW.user_id;
        IF secrets_count >= 10 THEN
          RAISE EXCEPTION 'user_identity_secrets limit (10) exceeded for user %', NEW.user_id
            USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    execute(<<~SQL.squish)
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON user_identity_secrets;
    SQL

    execute(<<~SQL.squish)
      DROP FUNCTION IF EXISTS #{FUNCTION_NAME}();
    SQL
  end
end
