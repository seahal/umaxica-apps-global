# typed: false
# frozen_string_literal: true

module Apex
  module App
    module Auth
      class CallbacksController < Apex::App::OpenController
        include ::Oidc::Callback
        include ::Oidc::RpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        provisions_oidc_rp_identity actor_class: "Client", identity_class: "ClientIdentity"

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "apex_app"
        end
      end
    end
  end
end
