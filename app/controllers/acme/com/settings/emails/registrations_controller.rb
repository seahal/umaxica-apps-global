# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Settings
      module Emails
        class RegistrationsController < Acme::Com::ApplicationController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_visitor!

          def create
            authorize!(VisitorEmail, to: :create?)
            issuance = IdentityEmailCeremonyGrantIssuer.issue!(
              surface: "com",
              actor_ref: current_visitor.public_id,
              session_ref: current_session_public_id,
              operation: "registration",
            )
            redirect_to(
              new_sign_com_settings_emails_registration_url(
                ri: params[:ri],
                email_ceremony_grant: issuance.grant,
                host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"),
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
            "settings_email"
          end
        end
      end
    end
  end
end
