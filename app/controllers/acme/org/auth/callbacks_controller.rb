# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Auth
      class CallbacksController < Acme::Org::ApplicationController
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
          # Shared browser RP client for Acme's local browser flow and Base launcher flows.
          # Base does not own this callback endpoint.
          "base-rails-rp"
        end
      end
    end
  end
end
