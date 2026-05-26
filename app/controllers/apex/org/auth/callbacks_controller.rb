# typed: false
# frozen_string_literal: true

module Apex
  module Org
    module Auth
      class CallbacksController < Apex::Org::OpenController
        include ::Oidc::Callback
        include ::Oidc::RpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        provisions_oidc_rp_identity actor_class: "Operator", identity_class: "OperatorIdentity"

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "apex_org"
        end
      end
    end
  end
end
