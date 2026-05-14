# typed: false
# frozen_string_literal: true

class VisitorPolicy < ApplicationPolicy
  def revoke_all?
    user.is_a?(Visitor) && user.id == record.id
  end

  def purge_sessions?
    user.is_a?(Operator)
  end
end
