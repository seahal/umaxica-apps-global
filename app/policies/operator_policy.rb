# typed: false
# frozen_string_literal: true

class OperatorPolicy < ApplicationPolicy
  # An operator may view their own account-scoped attributes (e.g. the birthdate page).
  def show?
    owner?
  end

  # An operator may update their own account-scoped attributes (e.g. the MFA level page).
  def update?
    owner?
  end

  def revoke_all?
    user.is_a?(Operator) && user.id == record.id
  end

  def purge_sessions?
    user.is_a?(Operator)
  end
end
