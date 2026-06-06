# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Settings
      module Telephones
        class RegistrationsController < Acme::Com::ApplicationController
          include ::VerificationVisitor

          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_visitor!

          def create
            authorize!(VisitorTelephone, to: :create?)
            issuance = IdentityTelephoneCeremonyGrantIssuer.issue!(
              surface: "com",
              actor_ref: current_visitor.public_id,
              session_ref: current_session_public_id,
              operation: "registration",
            )
            redirect_to(
              new_sign_com_settings_telephones_registration_url(
                ri: params[:ri],
                telephone_ceremony_grant: issuance.grant,
                host: ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
              ),
              status: :see_other,
              allow_other_host: cross_host_redirect_allowed?,
            )
          end

          private

          def verification_required_action?
            current_visitor&.verified_telephone?
          end

          def verification_scope
            "settings_telephone"
          end
        end
      end
    end
  end
end
