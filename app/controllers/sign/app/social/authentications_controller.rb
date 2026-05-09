# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Social
      # Controller for social auth entry points and account management
      #
      # Routes:
      #   POST   /social/auth/:provider/start -> #start (entry point with intent)
      #   DELETE /social/auth/:provider       -> #destroy (remove linked identity)
      #
      # The actual OmniAuth callbacks are handled by:
      #   Sign::App::Auth::OmniauthCallbacksController
      class AuthenticationsController < Sign::App::ApplicationController
        include ::Verification::User
        include SocialAuthConcern

        SUPPORTED_PROVIDERS = %w(google_app apple).freeze

        # Public access for start (login intent doesn't require auth)
        # For link/reauth intents, auth is checked in prepare_social_auth_intent!
        public_strict! only: %i(start)
        auth_required! only: %i(destroy)
        before_action -> { require_step_up!(scope: "social_unlink") }, only: :destroy

        # POST /social/auth/:provider/start
        # Entry point for social auth flow.
        # Prepares session with intent/state, then redirects to OmniAuth.
        #
        # Params:
        #   - provider: "google_app" or "apple"
        #   - intent: "login", "link", or "reauth" (default: "login")
        #
        # Flow:
        #   1. Validate provider
        #   2. Prepare intent in session (generates state)
        #   3. Redirect to /auth/:provider?state=...
        def start
          provider = params[:provider]
          intent = params[:intent] || "login"

          unless SUPPORTED_PROVIDERS.include?(provider)
            return redirect_to(
              new_sign_app_in_path,
              alert: I18n.t("sign.app.social.sessions.invalid_provider"),
            )
          end

          # Prepare session with intent context (OmniAuth manages OAuth state)
          state = prepare_social_auth_intent!(intent, provider: provider)

          safe_redirect_to(
            omniauth_authorize_path(provider, state: state),
            fallback: new_sign_app_in_path,
          )
        rescue SocialAuth::BaseError => e
          handle_social_auth_error(e)
        end

        # DELETE /social/auth/:provider
        # Removes a linked social identity from current user.
        def destroy
          provider = params[:provider]
          normalized_provider = SocialIdentifiable.normalize_provider(provider)

          ActiveRecord::Base.connected_to(role: :writing) do
            SocialAuthService.unlink(provider: provider, user: current_resource)
          end

          redirect_to(
            sign_app_configuration_path,
            notice: I18n.t(
              "sign.app.social.sessions.unlink.success",
              provider: normalized_provider.humanize,
            ),
          )
        rescue SocialAuth::BaseError => e
          redirect_to(sign_app_configuration_path, alert: e.message)
        end
      end
    end
  end
end
