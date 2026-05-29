# frozen_string_literal: true

class HardenVisitorLifecycleAndMfaConstraints < ActiveRecord::Migration[8.2]
  MFA_CONSTRAINT = "chk_visitors_mfa_requirement_consistency"
  TERMINATION_CONSTRAINT = "chk_visitors_terminated_requires_withdrawn"
  WITHDRAWAL_ORDER_CONSTRAINT = "chk_visitors_withdrawal_order"

  def up
    add_constraint_unless_exists(
      :visitors,
      "((multi_factor_enabled = FALSE AND multi_factor_id = 0) OR " \
      "(multi_factor_enabled = TRUE AND multi_factor_id <> 0))",
      MFA_CONSTRAINT,
    )
    add_constraint_unless_exists(
      :visitors,
      "(terminated_at IS NULL OR (withdrawn_at IS NOT NULL AND withdrawn_at < 'infinity'::timestamp))",
      TERMINATION_CONSTRAINT,
    )
    add_constraint_unless_exists(
      :visitors,
      "(withdrawal_started_at IS NULL OR withdrawn_at IS NULL OR withdrawn_at = 'infinity'::timestamp OR " \
      "withdrawal_started_at <= withdrawn_at)",
      WITHDRAWAL_ORDER_CONSTRAINT,
    )
  end

  def down
    remove_check_constraint(:visitors, name: MFA_CONSTRAINT, if_exists: true)
    remove_check_constraint(:visitors, name: TERMINATION_CONSTRAINT, if_exists: true)
    remove_check_constraint(:visitors, name: WITHDRAWAL_ORDER_CONSTRAINT, if_exists: true)
  end

  private

  def add_constraint_unless_exists(table, expression, name)
    return if check_constraint_exists?(table, name: name)

    add_check_constraint(table, expression, name: name, validate: false)
  end
end
