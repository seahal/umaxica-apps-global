# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class RecoverySecretsController < BaseController
        REVEAL_PURPOSE = "client.recovery_secret_credential"
        before_action :authenticate_client!
        before_action :authorize_secrets!, only: :show
        def show
          reveal = IdentityOneTimeReveal.consume!(
            actor: current_client, session_nonce: current_client.public_id,
            token: params[:token], purpose: REVEAL_PURPOSE,
          )
          @recovery_passcodes = Array(reveal&.value).map(&:to_s)
          @missing_recovery_passcodes = reveal.blank?
          @back_to_settings_url = base_app_identity_url(ri: params[:ri])
          render "shared/recovery_passcodes/show"
        end

        private

        def authorize_secrets! = authorize!(current_client, to: :show?)
      end
    end
  end
end
