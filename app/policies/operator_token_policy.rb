# typed: false
# frozen_string_literal: true

# Authorization for the org (operator) session inventory.
#
# `Sign::Org::Settings::SessionsController` lists the operator's own session tokens via
# `current_operator.staff_tokens.session_inventory`; ownership is enforced by that query. `index?`
# gates the actor *type* allowed to reach the listing. Mutation rules also keep the actor bound to
# operator-owned tokens instead of relying only on controller query scoping.
class OperatorTokenPolicy < ApplicationPolicy
  def index?
    user.is_a?(Operator)
  end

  # The session-detail page calls authorize!(@session) with the implicit `show?`
  # rule; without it the page raises instead of rendering. Viewing a session is
  # bound to its owner, exactly like revoking it.
  def show?
    owner?
  end

  def destroy?
    owner?
  end

  def revoke_others?
    user.is_a?(Operator) && record == OperatorToken
  end
end
