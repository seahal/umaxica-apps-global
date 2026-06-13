# typed: false
# frozen_string_literal: true

class OperatorLifecycleRequestPolicy < ApplicationPolicy
  def index?
    lifecycle_actor?
  end

  def show?
    lifecycle_actor?
  end

  def create?
    lifecycle_actor?
  end

  def approve?
    lifecycle_actor? && pending_request? && different_operator?
  end

  def reject?
    approve?
  end

  def execute?
    lifecycle_actor? && record.approved? && different_operator?
  end

  private

  # Overrides ApplicationPolicy#operator? which calls has_role? — a method that does not exist
  # on Operator (no Rolify, no org membership table). Type-check only; org ownership for JOIN
  # requests is enforced by OrgOperatorLifecycleRequestCreate at the service layer.
  def lifecycle_actor?
    user.is_a?(Operator)
  end

  def pending_request?
    record.respond_to?(:pending?) && record.pending?
  end

  def different_operator?
    record.requested_by_operator_id != user.id
  end
end
