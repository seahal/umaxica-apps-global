# frozen_string_literal: true

# adr/unified-enforcement.md, Principal effects. One row per Case declaring its
# account-wide consequence. `access_blocking` is the Case's declared intent to
# call AdministrativeAccessLock -- it never becomes a second runtime access
# state (adr/unified-enforcement.md, Administrative Access Lock integration).
class CreateAppEnforcementPrincipalEffects < ActiveRecord::Migration[8.2]
  def up
    create_table(:app_enforcement_principal_effects) do |t|
      t.references(:app_enforcement_case, null: false, foreign_key: true, index: { unique: true })
      t.string(:principal_public_id, null: false)

      t.boolean(:access_blocking, null: false, default: false)
      t.boolean(:recovery_blocked, null: false, default: false)
      t.boolean(:reactivation_blocked, null: false, default: false)
      t.boolean(:withdrawal_purge_blocked, null: false, default: false)
      t.boolean(:principal_hard_delete_blocked, null: false, default: false)
      t.string(:profile_effect)

      t.datetime(:effective_at, null: false)
      t.datetime(:expires_at)
      t.datetime(:ended_at)

      t.timestamps

      t.index(%i(principal_public_id ended_at), name: "idx_app_enforcement_principal_effects_principal_open")
    end
  end

  def down
    drop_table(:app_enforcement_principal_effects)
  end
end
