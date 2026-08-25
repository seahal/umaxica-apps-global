# frozen_string_literal: true

# adr/unified-enforcement.md, Identifier effects / HMAC / Encryption. No foreign
# key to any principal (Purge protection) -- these rows must outlive the account
# they originated from. `lookup_digest` uses a dedicated per-realm HMAC key,
# distinct from IdentifierBlindIndex's credential-lookup key (D6), with version
# columns supporting online rotation unlike the credential-table rotation
# contract (adr/identifier-hmac-emergency-rotation.md).
class CreateAppEnforcementIdentifierEffects < ActiveRecord::Migration[8.2]
  def up
    create_table(:app_enforcement_identifier_effects) do |t|
      t.references(:app_enforcement_case, null: false, foreign_key: true)
      t.string(:identifier_kind, null: false)
      t.string(:lookup_digest, null: false)
      t.integer(:key_version, null: false)
      t.integer(:digest_version, null: false)
      t.integer(:normalization_version, null: false)
      t.text(:display_value)

      t.boolean(:registration_blocked, null: false, default: false)
      t.boolean(:attachment_blocked, null: false, default: false)
      t.boolean(:recovery_blocked, null: false, default: false)

      t.datetime(:effective_at, null: false)
      t.datetime(:expires_at)
      t.datetime(:ended_at)

      t.timestamps

      t.index(
        %i(identifier_kind lookup_digest),
        unique: true,
        where: "ended_at IS NULL",
        name: "idx_app_enforcement_identifier_effects_one_open",
      )

      t.check_constraint(
        "identifier_kind IN ('email', 'telephone', 'google_subject', 'apple_subject', 'identity_id')",
        name: "chk_app_enforcement_identifier_effects_kind",
      )
    end
  end

  def down
    drop_table(:app_enforcement_identifier_effects)
  end
end
