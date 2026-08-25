# frozen_string_literal: true

# adr/unified-enforcement.md, Authentication method effects (com realm vocabulary
# -- no google/apple/totp/entra; Visitor has no social or TOTP credentials).
class CreateComEnforcementAuthenticationMethodEffects < ActiveRecord::Migration[8.2]
  METHODS = %w(email telephone secret passkey).freeze

  def up
    create_table(:com_enforcement_authentication_method_effects) do |t|
      t.references(:com_enforcement_case, null: false, foreign_key: true)
      t.string(:principal_public_id, null: false)
      t.string(:authentication_method, null: false)
      t.string(:effect, null: false)

      t.datetime(:effective_at, null: false)
      t.datetime(:expires_at)
      t.datetime(:ended_at)

      t.timestamps

      t.index(
        %i(principal_public_id authentication_method),
        unique: true,
        where: "ended_at IS NULL",
        name: "idx_com_enforcement_method_effects_one_open_per_method",
      )

      t.check_constraint(
        "authentication_method IN (#{METHODS.map { |m| "'#{m}'" }.join(", ")})",
        name: "chk_com_enforcement_method_effects_method",
      )
      t.check_constraint(
        "effect IN ('mutation_locked', 'unusable', 'permanently_frozen')",
        name: "chk_com_enforcement_method_effects_effect",
      )
    end
  end

  def down
    drop_table(:com_enforcement_authentication_method_effects)
  end
end
