# frozen_string_literal: true

# adr/unified-enforcement.md, Principal links. Reinstatement creates a
# reinstated_principal link on the original Case; the Case itself is never
# deleted or rewritten.
class CreateOrgEnforcementPrincipalLinks < ActiveRecord::Migration[8.2]
  def up
    create_table(:org_enforcement_principal_links) do |t|
      t.references(:org_enforcement_case, null: false, foreign_key: true)
      t.string(:principal_kind, null: false)
      t.string(:principal_public_id, null: false)
      t.string(:relationship_kind, null: false)

      t.datetime(:linked_at, null: false)
      t.datetime(:ended_at)

      t.timestamps

      t.index(:principal_public_id)

      t.check_constraint(
        "relationship_kind IN (" \
        "'target_principal', 'former_principal', 'related_principal', " \
        "'suspected_duplicate', 'reinstated_principal', 'false_positive')",
        name: "chk_org_enforcement_principal_links_relationship_kind",
      )
    end
  end

  def down
    drop_table(:org_enforcement_principal_links)
  end
end
