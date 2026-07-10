# typed: false
# frozen_string_literal: true

module AuthenticationCredentialInventoryReader
  extend ActiveSupport::Concern

  private

  def credential_inventory(actor = current_inventory_actor, excluding: nil, reload: true)
    AuthenticationCredentialInventory.call(actor, excluding: excluding, reload: reload)
  end

  def current_credential_inventory(excluding: nil, reload: true)
    credential_inventory(current_inventory_actor, excluding: excluding, reload: reload)
  end

  def current_inventory_actor
    return current_operator if respond_to?(:current_operator, true) && current_operator
    return current_visitor if respond_to?(:current_visitor, true) && current_visitor
    return current_client if respond_to?(:current_client, true) && current_client

    actor = Actor.actor if defined?(Actor)
    actor unless actor.respond_to?(:unauthenticated?) && actor.unauthenticated?
  end
end
