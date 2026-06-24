# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class SecretsController < ::Sign::Com::ApplicationController
        AUTHENTICATION_MODE = :private
        REVEAL_PURPOSE = "visitor.recovery_secret_credential"

        before_action :authenticate_visitor!
        before_action :authorize_secrets!, only: :show

        def show
          reveal = IdentityOneTimeReveal.consume!(
            actor: current_visitor,
            session_nonce: current_visitor.public_id,
            token: params[:token],
            purpose: REVEAL_PURPOSE,
          )

          if reveal
            @recovery_passcodes = Array(reveal.value).map(&:to_s)
            @back_to_settings_url = sign_com_settings_url(ri: params[:ri])
          else
            @missing_recovery_passcodes = true
            @back_to_settings_url = sign_com_settings_url(ri: params[:ri])
          end
        end

        private

        def authorize_secrets!
          authorize!(current_visitor, to: :show?)
        end
      end
    end
  end
end
