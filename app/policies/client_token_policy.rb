# typed: false
# frozen_string_literal: true

# Authorization for the app (client) session listing.
#
# `Sign::App::Configuration::SessionsController` lists the client's own session tokens via
# `current_client.client_tokens.session_inventory`; ownership is enforced by that query. `index?`
# gates the actor *type* allowed to reach the listing. Other defaults stay deny-all (allowlist).
class ClientTokenPolicy < ApplicationPolicy
  def index?
    user.is_a?(Client)
  end
end
