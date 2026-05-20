# typed: false
# frozen_string_literal: true

module Apex
  module App
    module Auth
      class CallbacksController < Apex::App::OpenController
        include ::Oidc::Callback

        private

        def oidc_client_id
          "apex_app"
        end

        def provision_rp_account_from_id_token!(payload)
          Client.find(payload.fetch("sub"))
        end
      end
    end
  end
end
