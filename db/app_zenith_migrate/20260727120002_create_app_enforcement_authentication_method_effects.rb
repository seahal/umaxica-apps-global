# frozen_string_literal: true

# adr/unified-enforcement.md, Authentication method effects (app realm vocabulary).
# Grain is (principal, authentication_method), not a credential row -- required so
# that forbidding the *addition* of a method the principal does not yet have is
# expressible. google/apple permanently_frozen is blocked until the common-storage
# cutover (D20, Trigger design) because no trigger protects those tables yet.
class CreateAppEnforcementAuthenticationMethodEffects < ActiveRecord::Migration[8.2]
  METHODS = %w(email telephone secret passkey totp google apple).freeze

  def up
    create_table(:app_enforcement_authentication_method_effects) do |t|
      t.references(:app_enforcement_case, null: false, foreign_key: true)
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
        name: "idx_app_enforcement_method_effects_one_open_per_method",
      )

      t.check_constraint(
        "authentication_method IN (#{METHODS.map { |m| "'#{m}'" }.join(", ")})",
        name: "chk_app_enforcement_method_effects_method",
      )
      t.check_constraint(
        "effect IN ('mutation_locked', 'unusable', 'permanently_frozen')",
        name: "chk_app_enforcement_method_effects_effect",
      )
      t.check_constraint(
        "effect != 'permanently_frozen' OR authentication_method NOT IN ('google', 'apple')",
        name: "chk_app_enforcement_method_effects_no_social_freeze",
      )
    end
  end

  def down
    drop_table(:app_enforcement_authentication_method_effects)
  end
end
