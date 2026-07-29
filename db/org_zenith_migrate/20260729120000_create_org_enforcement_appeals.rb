# frozen_string_literal: true

class CreateOrgEnforcementAppeals < ActiveRecord::Migration[8.2]
  def change
    create_table(:org_enforcement_appeals) do |t|
      t.references(:org_enforcement_case, null: false, foreign_key: true, index: { unique: true })
      t.string(:public_id, null: false)
      t.string(:state, null: false, default: "submitted")
      t.string(:reason_code, null: false)
      t.text(:statement)
      t.datetime(:submitted_at, null: false)
      t.datetime(:reviewed_at)
      t.string(:reviewer_operator_public_id)
      t.string(:resolution_code)
      t.datetime(:redacted_at)
      t.timestamps
    end

    add_index(:org_enforcement_appeals, :public_id, unique: true)
    add_check_constraint(
      :org_enforcement_appeals,
      "state IN ('submitted', 'under_review', 'approved', 'rejected', 'redacted')",
      name: "chk_org_enforcement_appeals_state",
    )
  end
end
