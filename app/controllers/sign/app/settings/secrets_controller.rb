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
          redirect_to(
            acme_app_identity_recovery_secret_path(ri: params[:ri], token: params[:token]),
            status: :see_other,
          )
        end

        private

        def authorize_secrets!
          authorize!(current_client, to: :show?)
        end
      end
    end
  end
end
