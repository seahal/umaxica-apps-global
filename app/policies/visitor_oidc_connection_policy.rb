# typed: false
# frozen_string_literal: true

# Authorization for the com (visitor) OIDC connection listing.
#
# `Sign::Com::Settings::ConnectionsController` already scopes every query to
# `current_visitor.oidc_connections`, so row-level ownership is enforced by the controller.
# This policy gates the actor *type* allowed to reach a listing at all (defense in depth on the
# com surface). `show` shares the rule because the controller exposes the same owned resource.
class VisitorOidcConnectionPolicy < ApplicationPolicy
  def index?
    user.is_a?(Visitor)
  end

  alias_method :show?, :index?

  # Unlinking a connection acts on a specific owned record; require ownership.
  def destroy?
    owner?
  end
end
