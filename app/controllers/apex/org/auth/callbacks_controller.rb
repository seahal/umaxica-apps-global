# typed: false
# frozen_string_literal: true

module Apex
  module Org
    module Auth
      class CallbacksController < Apex::Org::OpenController
        include ::Oidc::Callback

        AUTHENTICATION_MODE = :open

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "apex_org"
        end

        def provision_rp_account_from_id_token!(payload)
          Operator.find(payload.fetch("sub"))
        end
      end
    end
  end
end
