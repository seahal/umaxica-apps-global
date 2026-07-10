# typed: false
# frozen_string_literal: true

# Authorization for the org (operator) withdrawal surface.
#
# `Sign::Org::Settings::WithdrawalsController` only renders the operator's own withdrawal
# landing page (the actual request is filed through OperatorLifecycleRequest), so authorization is
# an owner-self read on `current_operator`. The withdrawal step-up scope guard remains on the
# controller's verification before_actions.
class OperatorWithdrawalPolicy < ApplicationPolicy
  def show?
    owner?
  end
end
