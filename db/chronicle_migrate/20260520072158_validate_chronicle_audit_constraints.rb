# frozen_string_literal: true

class ValidateChronicleAuditConstraints < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint(
      :chronicle_retention_policies,
      name: "chk_chronicle_retention_policies_permanent_duration"
    )
    validate_check_constraint(:chronicles, name: "chk_chronicles_result")
  end
end
