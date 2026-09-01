# frozen_string_literal: true

# EnforcementCaseApplicable::END_REASONS gained "verification_completed" when
# verification-released security locks were introduced, but the table's check
# constraint was never widened. Base::App::Identity::Recovery::CompletionsController
# ends the case with exactly that reason, so every completed recovery raised
# PG::CheckViolation. Widen the constraint to the reason set the model allows.
class AllowVerificationCompletedAppEnforcementCaseEndReason < ActiveRecord::Migration[8.2]
  # The widened constraint is a strict superset of the previous one, so no existing
  # row can violate it; validation therefore only needs the non-blocking form that
  # strong_migrations requires outside a DDL transaction.
  disable_ddl_transaction!

  CONSTRAINT = "chk_app_enforcement_cases_end_reason"
  WIDENED = "end_reason IS NULL OR end_reason IN (" \
            "'expired', 'revoked', 'superseded', 'corrected', 'appeal_approved', " \
            "'break_glass_released', 'verification_completed')"
  PREVIOUS = "end_reason IS NULL OR end_reason IN (" \
             "'expired', 'revoked', 'superseded', 'corrected', 'appeal_approved', " \
             "'break_glass_released')"

  def up
    remove_check_constraint(:app_enforcement_cases, name: CONSTRAINT, if_exists: true)
    add_check_constraint(:app_enforcement_cases, WIDENED, name: CONSTRAINT, validate: false)
    validate_check_constraint(:app_enforcement_cases, name: CONSTRAINT)
  end

  def down
    remove_check_constraint(:app_enforcement_cases, name: CONSTRAINT, if_exists: true)
    add_check_constraint(:app_enforcement_cases, PREVIOUS, name: CONSTRAINT, validate: false)
  end
end
