# typed: false
# frozen_string_literal: true

class ClientWebauthnCredentialPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && record_owner?
  end

  def create?
    user.present?
  end

  def update?
    user.present? && record_owner?
  end

  def destroy?
    user.present? && record_owner?
  end

  private

  def record_owner?
    record.user_id == user&.id
  end
end
