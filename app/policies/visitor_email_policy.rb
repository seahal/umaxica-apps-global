# typed: false
# frozen_string_literal: true

# Authorization for the com (visitor) email listing.
#
# `Sign::Com::Settings::EmailsController` and its registration subcontroller scope every
# query to `current_visitor.visitor_emails`, so row-level ownership is enforced by those queries.
# `index?`/`create?` gate the actor *type*; the per-record write rules require ownership
# (record.visitor_id == visitor.id). Other defaults stay deny-all (allowlist).
class VisitorEmailPolicy < ApplicationPolicy
  def index?
    user.is_a?(Visitor)
  end

  # Registration (new/create) is a fresh, unsaved record; gate by actor type. new? aliases create?.
  def create?
    user.is_a?(Visitor)
  end

  # Per-record management of an owned email. edit? aliases update?.
  def update?
    owner?
  end

  def destroy?
    owner?
  end
end
