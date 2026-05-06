# typed: false
# frozen_string_literal: true

# Authorization policy for ComContact resources (Corporate contact inquiries)
# Staff members handle contacts, users can only see their own
class ComContactPolicy < ApplicationPolicy
  def index?
    # Only staff with viewing permissions can see contact list
    actor.is_a?(Staff) && can_view?
  end

  def show?
    # Staff with viewing permissions or the contact creator
    (actor.is_a?(Staff) && can_view?) || owner?
  end

  def create?
    # Anyone can create a contact inquiry (public form)
    # But if authenticated, must be a User (not Staff)
    actor.nil? || actor.is_a?(User)
  end

  def update?
    # Only managers and above can update contact status/response
    actor.is_a?(Staff) && operator_or_manager?
  end

  def destroy?
    # Only operators can delete contacts
    actor.is_a?(Staff) && operator?
  end

  relation_scope do |relation|
    if actor.is_a?(Staff) && operator_or_manager?
      # Staff managers see all contacts
      relation.all
    elsif actor.is_a?(Staff)
      # Other staff see assigned or unassigned contacts
      relation.where(staff_id: [actor.id, nil])
    elsif actor.is_a?(User)
      # Users see only their own contact inquiries
      relation.where(user_id: actor.id)
    else
      # Unauthenticated users see nothing
      relation.none
    end
  end
end
