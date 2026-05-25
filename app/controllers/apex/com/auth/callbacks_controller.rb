# typed: false
# frozen_string_literal: true

module Apex
  module Com
    module Auth
      class CallbacksController < Apex::Com::OpenController
        include ::Oidc::Callback

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "apex_com"
        end

        def provision_rp_account_from_id_token!(payload)
          Visitor.find(payload.fetch("sub"))
        end
      end
    end
  end
end
