# typed: false
# frozen_string_literal: true

class OrgStaffPolicy < ApplicationPolicy
  def index?
    staff_area_access?
  end

  def show?
    staff_area_access?
  end

  private

  def staff_area_access?
    return false unless user.is_a?(Operator)

    delegated_operator_or_manager? || delegated_can_view?
  end

  def delegated_operator_or_manager?
    user.respond_to?(:operator_or_manager?) && operator_or_manager?
  end

  def delegated_can_view?
    user.respond_to?(:can_view?) && can_view?
  end
end
