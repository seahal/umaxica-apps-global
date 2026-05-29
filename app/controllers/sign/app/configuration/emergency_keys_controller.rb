# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class EmergencyKeysController < Sign::App::ApplicationController
        AUTHENTICATION_MODE = :private
        REVEAL_PURPOSE = "client.recovery_secret"

        before_action :authenticate_client!

        def show
          reveal = Identity::OneTimeReveal.consume!(
            actor: current_client,
            session_nonce: current_session_token&.public_id,
            token: params[:token],
            purpose: REVEAL_PURPOSE,
          )

          if reveal
            @raw_secret = reveal.value
            Identity::Audit.record!(
              actor: current_client,
              event_id: ClientChronicleEvent::RECOVERY_CODES_GENERATED,
              action: "recovery_secret.reveal",
              ip_address: request.remote_ip,
              user_agent: request.user_agent,
            )
          else
            flash.now[:alert] = t("sign.app.configuration.emergency_key.missing")
          end
        end
      end
    end
  end
end
