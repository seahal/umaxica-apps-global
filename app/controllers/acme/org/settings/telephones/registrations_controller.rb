# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Settings
      module Telephones
        class RegistrationsController < Acme::Org::ApplicationController
          include ::Verification::Operator

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_operator!

          def create
            authorize!(OperatorTelephone, to: :create?)
            issuance = Identity::TelephoneCeremony::GrantIssuer.issue!(
              surface: "org",
              actor_ref: current_operator.public_id,
              session_ref: current_session_public_id,
              operation: "registration",
            )
            redirect_to(
              new_sign_org_settings_telephones_registration_url(
                ri: params[:ri],
                telephone_ceremony_grant: issuance.grant,
                host: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
              ),
              status: :see_other,
              allow_other_host: cross_host_redirect_allowed?,
            )
          end

          private

          def verification_required_action?
            true
          end

          def verification_scope
            "settings_telephone"
          end
        end
      end
    end
  end
end
