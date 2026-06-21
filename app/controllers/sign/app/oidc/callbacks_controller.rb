# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Oidc
      # RP callback: completes the Acme OIDC session and provisions identity.
      class CallbacksController < ::Sign::App::ApplicationController
        include ::OidcCallback
        include ::OidcRpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        class_attribute :oidc_rp_actor_class_name, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_identity_class_name, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_bridge_class_name, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        provisions_oidc_rp_identity actor_class: "Client", identity_class: "ClientIdentity"
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
