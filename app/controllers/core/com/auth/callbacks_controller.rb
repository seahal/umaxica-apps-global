# typed: false
# frozen_string_literal: true

module Core
  module Com
    module Auth
      class CallbacksController < Core::Com::ApplicationController
        include ::Oidc::Callback
        include ::Oidc::RpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        provisions_oidc_rp_identity actor_class: "Visitor", identity_class: "VisitorIdentity",
                                    bridge_class: "CoreComVisitorBridge"

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "core_com"
        end
      end
    end
  end
end
