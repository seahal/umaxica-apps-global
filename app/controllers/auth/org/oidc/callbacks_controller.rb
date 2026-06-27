# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Oidc
      # RP callback: completes the Base OIDC session and provisions identity.
      class CallbacksController < ::Auth::Org::ApplicationController
        include ::OidcCallback
        include ::OidcRpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        class_attribute :oidc_rp_actor_class_name, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_identity_class_name, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_bridge_class_name, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        provisions_oidc_rp_identity actor_class: "Operator", identity_class: "OperatorIdentity"
        declare_authentication_mode! :open
        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "sign-rp"
        end
      end
    end
  end
end
