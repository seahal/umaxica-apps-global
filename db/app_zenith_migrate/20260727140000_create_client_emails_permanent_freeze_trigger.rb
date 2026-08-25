# frozen_string_literal: true

# adr/database-trigger-usage-boundary.md / adr/unified-enforcement.md, Trigger
# design: enforces that a `client_emails` row protected by a
# permanently_frozen Authentication Method Effect cannot be deleted by any
# route -- `delete_all`, ON DELETE CASCADE, or direct SQL -- none of which
# reach an ActiveRecord callback. The predicate is time-free
# (`ended_at IS NULL`, no `expires_at` comparison) because a permanent freeze
# has no expiry by construction (D8); the trigger never evaluates wall-clock
# and cannot be defeated by clock skew. Reads only app_zenith -- clients and
# app_enforcement_authentication_method_effects are both in this database.
class CreateClientEmailsPermanentFreezeTrigger < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        CREATE OR REPLACE FUNCTION enforcement_protect_client_emails_delete()
        RETURNS trigger AS $$
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM app_enforcement_authentication_method_effects AS effect
            JOIN clients ON clients.public_id = effect.principal_public_id
            WHERE clients.id = OLD.user_id
              AND effect.authentication_method = 'email'
              AND effect.effect = 'permanently_frozen'
              AND effect.ended_at IS NULL
          ) THEN
            RAISE EXCEPTION 'client_emails row % is protected by a permanently_frozen Authentication Method Effect', OLD.id
              USING ERRCODE = 'P0001';
          END IF;
          RETURN OLD;
        END;
        $$ LANGUAGE plpgsql;
      SQL

      execute(<<~SQL.squish)
        CREATE TRIGGER enforcement_protect_client_emails_delete
          BEFORE DELETE ON client_emails
          FOR EACH ROW
          EXECUTE FUNCTION enforcement_protect_client_emails_delete();
      SQL
    end
  end

  def down
    safety_assured do
      execute("DROP TRIGGER IF EXISTS enforcement_protect_client_emails_delete ON client_emails;")
      execute("DROP FUNCTION IF EXISTS enforcement_protect_client_emails_delete();")
    end
  end
end
