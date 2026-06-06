# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Settings
      module Telephones
        class RegistrationsController < Acme::App::ApplicationController
          include ::VerificationClient

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!

          def create
            authorize!(ClientTelephone, to: :create?)
            issuance = IdentityTelephoneCeremonyGrantIssuer.issue!(
              surface: "app",
              actor_ref: current_client.public_id,
              session_ref: current_session_public_id,
              operation: "registration",
            )
            redirect_to(
              new_sign_app_settings_telephones_registration_url(
                ri: params[:ri],
                telephone_ceremony_grant: issuance.grant,
                host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
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
