# typed: false
# frozen_string_literal: true

# Authorization for the org (operator) session listing.
#
# `Sign::Org::Configuration::SessionsController` lists the operator's own session tokens via
# `current_operator.staff_tokens.session_inventory`; ownership is enforced by that query. `index?`
# gates the actor *type* allowed to reach the listing. Other defaults stay deny-all (allowlist).
class OperatorTokenPolicy < ApplicationPolicy
  def index?
    user.is_a?(Operator)
  end
end
