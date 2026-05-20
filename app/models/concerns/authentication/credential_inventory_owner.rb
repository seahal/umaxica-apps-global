# typed: false
# frozen_string_literal: true

module Authentication
  module CredentialInventoryOwner
    extend ActiveSupport::Concern

    include Authentication::Aal1CredentialOwner
    include Authentication::Aal2CredentialOwner
    include Authentication::ContactabilityOwner

    def authentication_credential_inventory(excluding: nil, reload: false)
      Authentication::CredentialInventory.call(self, excluding: excluding, reload: reload)
    end

    def authentication_method_inventory(excluding: nil, reload: false)
      authentication_credential_inventory(excluding: excluding, reload: reload)
    end

    def aal3_methods(excluding: nil, reload: false)
      authentication_credential_inventory(excluding: excluding, reload: reload).aal3_methods
    end
  end
end
