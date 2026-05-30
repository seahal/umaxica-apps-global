# typed: false
# frozen_string_literal: true

# Authorization for the app (client) session inventory.
#
# `Sign::App::Configuration::SessionsController` lists the client's own session tokens via
# `current_client.client_tokens.session_inventory`; ownership is enforced by that query. `index?`
# gates the actor *type* allowed to reach the listing. Mutation rules also keep the actor bound to
# client-owned tokens instead of relying only on controller query scoping.
class ClientTokenPolicy < ApplicationPolicy
  def index?
    user.is_a?(Client)
  end

  def destroy?
    owner?
  end

  def revoke_others?
    user.is_a?(Client) && record == ClientToken
  end
end
