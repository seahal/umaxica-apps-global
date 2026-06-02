# typed: false
# frozen_string_literal: true

# Authorization for the app (client) self-service withdrawal flow.
#
# Every action in `Sign::App::Settings::WithdrawalsController` operates on `current_client`
# itself (schedule/deactivate/recover/terminate the actor's own account), so authorization is a
# pure owner-self check. This is deliberately NOT routed through `ClientPolicy`, whose `create?`/
# `destroy?` carry user-management semantics (operator-only) that do not apply to a client closing
# their own account. The withdrawal step-up scope guard remains on the controller's verification
# before_actions.
class ClientWithdrawalPolicy < ApplicationPolicy
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
