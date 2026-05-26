# typed: false
# frozen_string_literal: true

module Core
  module App
    module Auth
      class CallbacksController < OpenController
        include ::Oidc::Callback
        include ::Oidc::RpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        provisions_oidc_rp_identity actor_class: "Client", identity_class: "ClientIdentity",
                                    bridge_class: "CoreAppClientBridge"

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "core_app"
        end
      end
    end
  end
end
