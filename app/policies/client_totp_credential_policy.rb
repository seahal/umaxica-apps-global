# typed: false
# frozen_string_literal: true

# Authorization for the app (client) TOTP credential management.
#
# `Sign::App::Settings::TotpsController` scopes every lookup to
# `current_client.client_totp_credentials`, so row-level ownership is enforced by the controller.
# This policy adds object-level authorization: listing/registration are allowed for any client
# actor; per-record actions (edit/update/destroy) require ownership. Step-up freshness is enforced
# separately by the controller's verification before_actions.
class ClientTotpCredentialPolicy < ApplicationPolicy
  def index?
    user.is_a?(Client)
  end

  def create?
    user.is_a?(Client)
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

    relation.where(user_id: user.id)
  end
end
