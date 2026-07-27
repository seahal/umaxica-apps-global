# frozen_string_literal: true

# adr/unified-enforcement.md, Identifier effects / HMAC / Encryption. No foreign
# key to any principal (Purge protection). Org realm has no social login, so
# google_subject/apple_subject are not in this realm's identifier_kind
# vocabulary; Entra tenant+object-id identifiers are deferred (Future work).
class CreateOrgEnforcementIdentifierEffects < ActiveRecord::Migration[8.2]
  def up
    create_table(:org_enforcement_identifier_effects) do |t|
      t.references(:org_enforcement_case, null: false, foreign_key: true)
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
        name: "idx_org_enforcement_identifier_effects_one_open",
      )

      t.check_constraint(
        "identifier_kind IN ('email', 'telephone', 'identity_id')",
        name: "chk_org_enforcement_identifier_effects_kind",
      )
    end
  end

  def down
    drop_table(:org_enforcement_identifier_effects)
  end
end
