# typed: false
# frozen_string_literal: true

# Authorization for the com (visitor) passkey listing.
#
# `Sign::Com::Settings::PasskeysController` scopes every query to
# `current_visitor.visitor_passkeys`. `index?`/`create?` gate the actor *type*; the per-record
# rules require ownership (record.visitor_id == visitor.id). Mirrors ClientPasskeyPolicy.
class VisitorPasskeyPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    owner?
  end

  def create?
    user.present?
  end

  def new?
    create?
  end

  def update?
    owner?
  end

  def edit?
    update?
  end

  def destroy?
    owner?
  end

  relation_scope do |relation|
    return relation.none unless user

    relation.where(visitor_id: user.id)
  end
end
