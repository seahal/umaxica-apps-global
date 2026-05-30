# typed: false
# frozen_string_literal: true

# Authorization for the app (client) email listing.
#
# `Sign::App::Configuration::EmailsController` and its registration subcontroller scope every
# query to `current_client.client_emails`, so row-level ownership is enforced by those queries.
# `index?`/`create?` gate the actor *type*; the per-record write rules require ownership
# (record.user_id == client.id). Other defaults stay deny-all (allowlist).
class ClientEmailPolicy < ApplicationPolicy
  def index?
    user.is_a?(Client)
  end

  # Registration (new/create) is a fresh, unsaved record; gate by actor type. new? aliases create?.
  def create?
    user.is_a?(Client)
  end

  # Per-record management of an owned email. edit? aliases update?.
  def update?
    owner?
  end

  def destroy?
    owner?
  end
end
