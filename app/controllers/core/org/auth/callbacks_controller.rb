# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Auth
      class CallbacksController < OpenController
        include ::Oidc::Callback

        AUTHENTICATION_MODE = :open

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "core_org"
        end

        def provision_rp_account_from_id_token!(payload)
          Operator.find(payload.fetch("sub"))
        end
      end
    end
  end
end
