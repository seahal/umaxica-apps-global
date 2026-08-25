# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Authorization / Operator safety. Shared across
# all three realm-specific Case classes (set explicitly via `with:
# EnforcementCasePolicy` at the controller, since Action Policy's default
# class-name resolution would otherwise require one identical policy per
# realm). Operator self-action denial and approval separation are already
# enforced as CHECK constraints (D12) -- this policy is the operator-facing
# gate, not the sole boundary.
#
# D13 envisions realm-scoped permission *grants* (enforcement.app.apply_permanent_ban
# vs enforcement.com.apply_permanent_ban); this repository has no existing
# operator grant/role system to hang that on (OperatorPolicy itself only
# checks `user.is_a?(Operator)`), so that finer-grained matrix is not built
# here -- tracked as Future work in the ADR.
class EnforcementCasePolicy < ApplicationPolicy
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
    operator? && record.applied_by_operator_public_id != user.public_id
  end

  def release?
    operator?
  end

  def review_appeal?
    operator?
  end

  private

  def operator?
    user.is_a?(::Operator)
  end
end
