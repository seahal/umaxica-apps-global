# typed: false
# frozen_string_literal: true

class OperatorLifecycleRequestPolicy < ApplicationPolicy
  def index?
    operator?
  end

  def show?
    operator?
  end

  def create?
    operator?
  end

  def approve?
    operator? && pending_request? && different_operator?
  end

  def reject?
    approve?
  end

  def execute?
    operator? && record.approved? && different_operator?
  end

  private

  def operator?
    user.is_a?(Operator)
  end

  def pending_request?
    record.respond_to?(:pending?) && record.pending?
  end

  def different_operator?
    record.requested_by_operator_id != user.id
  end
end
