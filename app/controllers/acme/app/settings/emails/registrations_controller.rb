# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Settings
      module Emails
        class RegistrationsController < Acme::App::ApplicationController
          AUTHENTICATION_MODE = :private
          declare_authentication_mode! :private

          before_action :authenticate_client!

          def create
            authorize!(ClientEmail, to: :create?)
            issuance = Identity::EmailCeremony::GrantIssuer.issue!(
              surface: "app",
              actor_ref: current_client.public_id,
              session_ref: current_session_public_id,
              operation: "registration",
            )
            redirect_to(
              new_sign_app_settings_emails_registration_url(
                ri: params[:ri],
                email_ceremony_grant: issuance.grant,
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
            "settings_email"
          end
        end
      end
    end
  end
end
