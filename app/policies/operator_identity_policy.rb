# typed: false
# frozen_string_literal: true

class OperatorIdentityPolicy < ApplicationPolicy
  def destroy?
    owner?
  end
end
