# frozen_string_literal: true

# adr/unified-enforcement.md, Purge protection: blocks physical deletion of a
# `clients` row while an in-force Principal Effect has
# principal_hard_delete_blocked set. D9's CHECK constraints only allow
# principal_hard_delete_blocked on a permanent_ban Case, and permanent_ban
# requires expires_at IS NULL -- so this predicate is structurally time-free
# in practice even though it defensively re-checks the window inside the
# trigger. Uses clock_timestamp(), not now()/transaction_timestamp() --
# the latter is frozen at the enclosing transaction's BEGIN in PostgreSQL, so
# a Case whose effective_at is set to Time.current *after* a long-running
# transaction began would incorrectly read as "not yet effective" for the
# rest of that transaction.
class CreateClientsHardDeleteProtectionTrigger < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        CREATE OR REPLACE FUNCTION enforcement_protect_clients_delete()
        RETURNS trigger AS $$
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM app_enforcement_principal_effects AS effect
            JOIN app_enforcement_cases AS enforcement_case
              ON enforcement_case.id = effect.app_enforcement_case_id
            WHERE effect.principal_public_id = OLD.public_id
              AND effect.principal_hard_delete_blocked = TRUE
              AND effect.ended_at IS NULL
              AND enforcement_case.state = 'active'
              AND enforcement_case.ended_at IS NULL
              AND enforcement_case.effective_at <= clock_timestamp()
              AND (enforcement_case.expires_at IS NULL OR enforcement_case.expires_at > clock_timestamp())
          ) THEN
            RAISE EXCEPTION 'clients row % is protected by an in-force principal_hard_delete_blocked Principal Effect', OLD.id
              USING ERRCODE = 'P0001';
          END IF;
          RETURN OLD;
        END;
        $$ LANGUAGE plpgsql;
      SQL

      execute(<<~SQL.squish)
        CREATE TRIGGER enforcement_protect_clients_delete
          BEFORE DELETE ON clients
          FOR EACH ROW
          EXECUTE FUNCTION enforcement_protect_clients_delete();
      SQL
    end
  end

  def down
    safety_assured do
      execute("DROP TRIGGER IF EXISTS enforcement_protect_clients_delete ON clients;")
      execute("DROP FUNCTION IF EXISTS enforcement_protect_clients_delete();")
    end
  end
end
