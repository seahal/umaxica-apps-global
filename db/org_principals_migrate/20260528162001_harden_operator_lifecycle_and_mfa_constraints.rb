# frozen_string_literal: true

class HardenOperatorLifecycleAndMfaConstraints < ActiveRecord::Migration[8.2]
  MFA_CONSTRAINT = "chk_operators_mfa_requirement_consistency"
  WITHDRAWAL_ORDER_CONSTRAINT = "chk_operators_withdrawal_order"

  def up
    add_constraint_unless_exists(
      :operators,
      "((multi_factor_enabled = FALSE AND multi_factor_id = 0) OR " \
      "(multi_factor_enabled = TRUE AND multi_factor_id <> 0))",
      MFA_CONSTRAINT,
    )
    add_constraint_unless_exists(
      :operators,
      "(withdrawal_started_at IS NULL OR withdrawn_at IS NULL OR withdrawal_started_at <= withdrawn_at)",
      WITHDRAWAL_ORDER_CONSTRAINT,
    )
  end

  def down
    remove_check_constraint(:operators, name: MFA_CONSTRAINT, if_exists: true)
    remove_check_constraint(:operators, name: WITHDRAWAL_ORDER_CONSTRAINT, if_exists: true)
  end

  private

  def add_constraint_unless_exists(table, expression, name)
    return if check_constraint_exists?(table, name: name)

    add_check_constraint(table, expression, name: name, validate: false)
  end
end
