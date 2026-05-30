# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class EmergencyKeysController < Sign::App::ApplicationController
        AUTHENTICATION_MODE = :private
        REVEAL_PURPOSE = "client.recovery_secret_credential"

        before_action :authenticate_client!
        # Object-level authorization (ActionPolicy): only the owner may reveal their own recovery
        # secret. The one-time token (Identity::OneTimeReveal) still gates the actual value below.
        before_action :authorize_emergency_key!, only: :show

        def show
          reveal = Identity::OneTimeReveal.consume!(
            actor: current_client,
            session_nonce: current_session_token&.public_id,
            token: params[:token],
            purpose: REVEAL_PURPOSE,
          )

          if reveal
            @raw_secret_credential = reveal.value
            Identity::Audit.record!(
              actor: current_client,
              event_id: ClientChronicleEvent::RECOVERY_CODES_GENERATED,
              action: "recovery_secret_credential.reveal",
              ip_address: request.remote_ip,
              user_agent: request.user_agent,
            )
          else
            flash.now[:alert] = t("sign.app.configuration.emergency_key.missing")
          end
        end

        private

        def authorize_emergency_key!
          authorize!(current_client, to: :show?)
        end
      end
    end
  end
end
