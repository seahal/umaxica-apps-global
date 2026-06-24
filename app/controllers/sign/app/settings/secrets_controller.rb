# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      class SecretsController < ::Sign::App::ApplicationController
        AUTHENTICATION_MODE = :private
        REVEAL_PURPOSE = "client.recovery_secret_credential"

        before_action :authenticate_client!
        # Object-level authorization (ActionPolicy): only the owner may reveal their own recovery
        # secret. The one-time token (IdentityOneTimeReveal) still gates the actual value below.
        before_action :authorize_secrets!, only: :show

        def show
          reveal = IdentityOneTimeReveal.consume!(
            actor: current_client,
            session_nonce: current_client.public_id,
            token: params[:token],
            purpose: REVEAL_PURPOSE,
          )

          if reveal
            @recovery_passcodes = Array(reveal.value).map(&:to_s)
            @back_to_settings_url = sign_app_settings_url(ri: params[:ri])
            IdentityAudit.record!(
              actor: current_client,
              event_id: ClientChronicleEvent::RECOVERY_CODES_GENERATED,
              action: "recovery_secret_credential.reveal",
              ip_address: request.remote_ip,
              user_agent: request.user_agent,
            )
          else
            @missing_recovery_passcodes = true
            @back_to_settings_url = sign_app_settings_url(ri: params[:ri])
          end
        end

        private

        def authorize_secrets!
          authorize!(current_client, to: :show?)
        end
      end
    end
  end
end
