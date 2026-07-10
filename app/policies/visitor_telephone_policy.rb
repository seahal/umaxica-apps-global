# typed: false
# frozen_string_literal: true

# Authorization for the com (visitor) telephone listing.
#
# `Sign::Com::Settings::TelephonesController` and its registration subcontroller scope every
# query to `current_visitor.visitor_telephones`, so row-level ownership is enforced by those queries.
# `index?`/`create?` gate the actor *type*; per-record write rules require ownership
# (record.visitor_id == visitor.id). Other defaults stay deny-all (allowlist).
class VisitorTelephonePolicy < ApplicationPolicy
  def index?
    user.is_a?(Visitor)
  end

  # Registration (new/create) is a fresh, unsaved record; gate by actor type. new? aliases create?.
  def create?
    user.is_a?(Visitor)
  end

  # Per-record management of an owned telephone. edit? aliases update?.
  def update?
    owner?
  end

  def destroy?
    owner?
  end
end
