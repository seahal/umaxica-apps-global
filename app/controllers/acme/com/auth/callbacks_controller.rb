# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Auth
      class CallbacksController < Acme::Com::ApplicationController
        include ::Oidc::Callback
        include ::Oidc::RpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        provisions_oidc_rp_identity actor_class: "Visitor", identity_class: "VisitorIdentity"

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "acme_com"
        end
      end
    end
  end
end
