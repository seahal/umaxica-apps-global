# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Social
      # Controller for staff social auth entry point.
      #
      # Routes:
      #   POST /social/auth/:provider/start -> #start
      #
      # Only supports "login" intent -- staff sign-up via social is not allowed.
      class AuthenticationsController < Sign::Org::ApplicationController
        include SocialAuthConcern

        SUPPORTED_PROVIDERS = %w(google_org).freeze

        public_strict! only: %i(start)

        # POST /social/auth/:provider/start
        # Prepares intent/state in session, then redirects to OmniAuth provider.
        def start
          provider = params[:provider]

          unless SUPPORTED_PROVIDERS.include?(provider)
            return redirect_to(
              new_sign_org_in_path,
              alert: I18n.t("sign.org.social.sessions.invalid_provider"),
            )
          end

          state = prepare_social_auth_intent!("login", provider: provider)

          safe_redirect_to(
            omniauth_authorize_path(provider, state: state),
            fallback: new_sign_org_in_path,
          )
        rescue SocialAuth::BaseError => e
          handle_social_auth_error(e)
        end

        private

        def social_auth_failure_redirect_path
          new_sign_org_in_path
        end
      end
    end
  end
end
