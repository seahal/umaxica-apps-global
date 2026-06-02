# typed: false
# frozen_string_literal: true

# Authorization for the com (visitor) session inventory.
#
# `Sign::Com::Settings::SessionsController` lists the visitor's own session tokens via
# `current_visitor.visitor_tokens.session_inventory`; ownership is enforced by that query. `index?`
# gates the actor *type* allowed to reach the listing. Mutation rules also keep the actor bound to
# visitor-owned tokens instead of relying only on controller query scoping.
class VisitorTokenPolicy < ApplicationPolicy
  def index?
    user.is_a?(Visitor)
  end

  def destroy?
    owner?
  end

  def revoke_others?
    user.is_a?(Visitor) && record == VisitorToken
  end
end
