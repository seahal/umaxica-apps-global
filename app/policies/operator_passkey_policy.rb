# typed: false
# frozen_string_literal: true

# Authorization for the org (operator) passkey listing.
#
# `Sign::Org::Settings::PasskeysController` scopes every query to
# `current_operator.staff_passkeys`. `index?`/`create?` gate the actor *type*; the per-record
# rules require ownership (record.staff_id == operator.id). Mirrors ClientPasskeyPolicy.
class OperatorPasskeyPolicy < ApplicationPolicy
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

    relation.where(staff_id: user.id)
  end
end
