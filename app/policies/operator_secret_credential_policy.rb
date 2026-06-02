# typed: false
# frozen_string_literal: true

# Authorization for the org (operator) secret-credential management.
#
# `Sign::Org::Settings::SecretCredentialsController` scopes every lookup to
# `current_operator.staff_secret_credentials`, so row-level ownership is enforced by the
# controller. This policy adds object-level authorization: listing/registration are allowed for
# any operator actor; per-record actions require ownership (record.staff_id == user.id). Step-up
# and Turnstile guards remain on the controller's verification before_actions.
class OperatorSecretCredentialPolicy < ApplicationPolicy
  def index?
    user.is_a?(Operator)
  end

  def create?
    user.is_a?(Operator)
  end

  def new?
    create?
  end

  def show?
    owner?
  end

  def update?
    owner?
  end

  def edit?
    update?
  end

  def destroy?
    owner?
  end

  relation_scope do |relation|
    return relation.none unless user

    relation.where(staff_id: user.id)
  end
end
