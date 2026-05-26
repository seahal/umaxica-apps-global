# typed: false
# frozen_string_literal: true

module Core
  module App
    module Auth
      class CallbacksController < OpenController
        include ::Oidc::Callback

        AUTHENTICATION_MODE = :open

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "core_app"
        end

        def provision_rp_account_from_id_token!(payload)
          Client.find(payload.fetch("sub"))
        end
      end
    end
  end
end
