# typed: false
# frozen_string_literal: true

class OperatorPreferencePolicy < ApplicationPolicy
  def update?
    user.is_a?(Operator) && record.is_a?(OperatorPreference) && record.staff_id == user.id
  end
end
