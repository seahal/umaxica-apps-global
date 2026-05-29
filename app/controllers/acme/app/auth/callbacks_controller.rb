# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Auth
      class CallbacksController < Acme::App::ApplicationController
        include ::Oidc::Callback
        include ::Oidc::RpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        provisions_oidc_rp_identity actor_class: "Client", identity_class: "ClientIdentity"

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "acme_app"
        end
      end
    end
  end
end
