# typed: false
# frozen_string_literal: true

# Authorization for the com (visitor) self-service withdrawal flow.
#
# Every action in `Sign::Com::Configuration::WithdrawalsController` operates on `current_visitor`
# itself, so authorization is a pure owner-self check. Deliberately not routed through
# `VisitorPolicy` so the withdrawal verbs stay independent of any future account-management rules.
# The withdrawal step-up scope guard remains on the controller's verification before_actions.
class VisitorWithdrawalPolicy < ApplicationPolicy
  # new? -> create?, edit? -> update? via ApplicationPolicy aliases.
  def create?
    owner?
  end

  def update?
    owner?
  end

  def destroy?
    owner?
  end
end
