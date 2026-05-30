# typed: false
# frozen_string_literal: true

# Authorization for the org (operator) OIDC connection listing.
#
# `Sign::Org::Configuration::ConnectionsController` already scopes every query to
# `current_operator.oidc_connections`, so row-level ownership is enforced by the controller.
# This policy gates the actor *type* allowed to reach a listing at all (defense in depth on the
# org surface). `show` shares the rule because the controller exposes the same owned resource.
class OperatorOidcConnectionPolicy < ApplicationPolicy
  def index?
    user.is_a?(Operator)
  end

  alias_method :show?, :index?

  # Unlinking a connection acts on a specific owned record; require ownership.
  def destroy?
    owner?
  end
end
