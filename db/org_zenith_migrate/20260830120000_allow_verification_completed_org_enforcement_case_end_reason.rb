# frozen_string_literal: true

# Staff-surface counterpart of the app and com migrations with the same name.
# The three enforcement-case tables share EnforcementCaseApplicable, so the
# end_reason constraint has to accept the same reason set on all three.
class AllowVerificationCompletedOrgEnforcementCaseEndReason < ActiveRecord::Migration[8.2]
  # The widened constraint is a strict superset of the previous one, so no existing
  # row can violate it; validation therefore only needs the non-blocking form that
  # strong_migrations requires outside a DDL transaction.
  disable_ddl_transaction!

  CONSTRAINT = "chk_org_enforcement_cases_end_reason"
  WIDENED = "end_reason IS NULL OR end_reason IN (" \
            "'expired', 'revoked', 'superseded', 'corrected', 'appeal_approved', " \
            "'break_glass_released', 'verification_completed')"
  PREVIOUS = "end_reason IS NULL OR end_reason IN (" \
             "'expired', 'revoked', 'superseded', 'corrected', 'appeal_approved', " \
             "'break_glass_released')"

  def up
    remove_check_constraint(:org_enforcement_cases, name: CONSTRAINT, if_exists: true)
    add_check_constraint(:org_enforcement_cases, WIDENED, name: CONSTRAINT, validate: false)
    validate_check_constraint(:org_enforcement_cases, name: CONSTRAINT)
  end

  def down
    remove_check_constraint(:org_enforcement_cases, name: CONSTRAINT, if_exists: true)
    add_check_constraint(:org_enforcement_cases, PREVIOUS, name: CONSTRAINT, validate: false)
  end
end
