# typed: false
# frozen_string_literal: true

module Apex
  module Com
    module Auth
      class CallbacksController < Apex::Com::OpenController
        include ::Oidc::Callback
        include ::Oidc::RpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        provisions_oidc_rp_identity actor_class: "Visitor", identity_class: "VisitorIdentity"

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "apex_com"
        end
      end
    end
  end
end
