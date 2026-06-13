# typed: false
# frozen_string_literal: true

# Authorization for the app (client) OIDC connection listing.
#
# `Acme::App::Settings::ConnectionsController` already scopes every query to
# `current_client.oidc_connections`, so row-level ownership is enforced by the controller.
# This policy gates the actor *type* allowed to reach a listing at all (defense in depth on the
# app surface). `show` shares the rule because the controller exposes the same owned resource.
class ClientOidcConnectionPolicy < ApplicationPolicy
  def index?
    user.is_a?(Client)
  end

  alias_method :show?, :index?

  # Unlinking a connection acts on a specific owned record; require ownership.
  def destroy?
    owner?
  end
end
