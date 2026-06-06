# typed: false
# frozen_string_literal: true

module AuthenticationCredentialInventoryOwner
  extend ActiveSupport::Concern

  include AuthenticationAal1CredentialOwner
  include AuthenticationAal2CredentialOwner
  include AuthenticationContactabilityOwner

  def authentication_credential_inventory(excluding: nil, reload: false)
    AuthenticationCredentialInventory.call(self, excluding: excluding, reload: reload)
  end

  def authentication_method_inventory(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload)
  end

  def aal3_methods(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).aal3_methods
  end
end
