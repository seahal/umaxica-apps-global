# typed: false
# frozen_string_literal: true

class OperatorPolicy < ApplicationPolicy
  def revoke_all?
    user.is_a?(Operator) && user.id == record.id
  end

  def purge_sessions?
    user.is_a?(Operator)
  end
end
