# typed: false
# frozen_string_literal: true

# Authorization for the com (visitor) session listing.
#
# `Sign::Com::Configuration::SessionsController` lists the visitor's own session tokens via
# `current_visitor.visitor_tokens.session_inventory`; ownership is enforced by that query. `index?`
# gates the actor *type* allowed to reach the listing. Other defaults stay deny-all (allowlist).
class VisitorTokenPolicy < ApplicationPolicy
  def index?
    user.is_a?(Visitor)
  end
end
