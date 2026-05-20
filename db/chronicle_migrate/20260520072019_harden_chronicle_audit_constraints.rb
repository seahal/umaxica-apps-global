# frozen_string_literal: true

class HardenChronicleAuditConstraints < ActiveRecord::Migration[8.2]
  CHRONICLE_RESULTS =
    "result IN ('intent', 'succeeded', 'failed', 'audit_incomplete', 'invalidated', 'manual_recovery_required')"

  def up
    unless check_constraint_exists?(
      :chronicle_retention_policies,
      name: "chk_chronicle_retention_policies_permanent_duration"
    )
      add_check_constraint(
        :chronicle_retention_policies,
        "permanent = false OR duration_days = 0",
        name: "chk_chronicle_retention_policies_permanent_duration",
        validate: false
      )
    end

    return if check_constraint_exists?(:chronicles, name: "chk_chronicles_result")

    add_check_constraint(:chronicles, CHRONICLE_RESULTS, name: "chk_chronicles_result", validate: false)
  end

  def down
    remove_check_constraint(
      :chronicles,
      name: "chk_chronicles_result",
      if_exists: true
    )
    remove_check_constraint(
      :chronicle_retention_policies,
      name: "chk_chronicle_retention_policies_permanent_duration",
      if_exists: true
    )
  end
end
