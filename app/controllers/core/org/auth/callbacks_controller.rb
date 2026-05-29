# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Auth
      class CallbacksController < Core::Org::ApplicationController
        include ::Oidc::Callback
        include ::Oidc::RpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        provisions_oidc_rp_identity actor_class: "Operator", identity_class: "OperatorIdentity",
                                    bridge_class: "CoreOrgOperatorBridge"

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "core_org"
        end
      end
    end
  end
end
