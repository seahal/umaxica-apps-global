# typed: false
# frozen_string_literal: true

# Authorization for the com (visitor) secret-credential management.
#
# `Sign::Com::Settings::SecretCredentialsController` scopes every lookup to
# `current_visitor.visitor_secret_credentials`, so row-level ownership is enforced by the
# controller. This policy adds object-level authorization: listing/registration are allowed for
# any visitor actor; per-record actions require ownership (record.visitor_id == user.id). Step-up
# and Turnstile guards remain on the controller's verification before_actions.
class VisitorSecretCredentialPolicy < ApplicationPolicy
  def index?
    user.is_a?(Visitor)
  end

  def create?
    user.is_a?(Visitor)
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

  def regenerate?
    owner?
  end

  relation_scope do |relation|
    return relation.none unless user

    relation.where(visitor_id: user.id)
  end
end
