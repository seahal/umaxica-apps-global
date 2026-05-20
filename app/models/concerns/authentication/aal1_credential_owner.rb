# typed: false
# frozen_string_literal: true

module Authentication
  module Aal1CredentialOwner
    extend ActiveSupport::Concern

    def aal1_methods(excluding: nil, reload: false)
      authentication_credential_inventory(excluding: excluding, reload: reload).aal1_methods
    end

    def login_methods(excluding: nil, reload: false)
      aal1_methods(excluding: excluding, reload: reload)
    end

    def aal1_method_count(excluding: nil, reload: false)
      authentication_credential_inventory(excluding: excluding, reload: reload).aal1_method_count
    end

    def aal1_available?(excluding: nil, reload: false)
      authentication_credential_inventory(excluding: excluding, reload: reload).aal1_available?
    end

    def login_available?(excluding: nil, reload: false)
      aal1_available?(excluding: excluding, reload: reload)
    end

    def retains_aal1_after?(excluding:, reload: false)
      aal1_available?(excluding: excluding, reload: reload)
    end

    def retains_login_after?(excluding:, reload: false)
      retains_aal1_after?(excluding: excluding, reload: reload)
    end
  end
end
