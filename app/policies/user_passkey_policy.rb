# typed: false
# frozen_string_literal: true

class UserPasskeyPolicy < ApplicationPolicy
  def index?
    actor.present?
  end

  def show?
    owner?
  end

  def create?
    actor.present?
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
    return relation.none unless actor

    relation.where(user_id: actor.id)
  end
end
