# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Social
      # Controller for social auth entry points and account management
      #
      # Routes:
      #   POST   /social/auth/:provider/continue -> #continue (default continue entry point)
      #   POST   /social/auth/:provider/start    -> #start (compatibility alias)
      #   DELETE /social/auth/:provider       -> #destroy (remove linked identity)
      #
      # The actual OmniAuth callbacks are handled by:
      #   Sign::App::Auth::OmniauthCallbacksController
      class AuthenticationsController < Sign::App::ApplicationController
        include ::Verification::User
        include SocialAuthConcern

        SUPPORTED_PROVIDERS = %w(google_app apple).freeze

        # Public access for continue/start (login intent doesn't require auth)
        # For link/reauth intents, auth is checked in prepare_social_auth_intent!
        public_strict! only: %i(continue start)
        auth_required! only: %i(destroy)
        before_action -> { require_step_up!(scope: "social_unlink") }, only: :destroy

        # POST /social/auth/:provider/continue
        # Entry point for social auth flow from sign-up and sign-in screens.
        # Prepares session with intent/state, then redirects to OmniAuth.
        #
        # Params:
        #   - provider: "google_app" or "apple"
        #   - intent: "login", "link", or "reauth" (default: "login")
        #     "login" is the internal continue flow: existing identities sign in,
        #     missing identities create a new account.
        #
        # Flow:
        #   1. Validate provider
        #   2. Prepare intent in session (generates state)
        #   3. Redirect to /auth/:provider?state=...
        def continue
          provider = params[:provider]
          intent = params[:intent] || "login"

          unless SUPPORTED_PROVIDERS.include?(provider)
            return redirect_to(
              new_sign_app_in_path,
              alert: I18n.t("sign.app.social.sessions.invalid_provider"),
            )
          end

          # Prepare session with intent context (OmniAuth manages OAuth state)
          state = prepare_social_auth_intent!(
            intent,
            provider: provider,
            rt: safe_encoded_rt(redirect_parameter_value),
            entry: social_auth_entry,
            ri: params[:ri].presence,
          )

          safe_redirect_to(
            omniauth_authorize_path(provider, state: state),
            fallback: new_sign_app_in_path,
          )
        rescue SocialAuth::BaseError => e
          handle_social_auth_error(e)
        end

        # POST /social/auth/:provider/start
        # Compatibility alias for older templates and tests.
        def start
          continue
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

        private

        def social_auth_entry
          return "sign_up" if params.expect(:entry).to_s == "sign_up"

          referer_path = URI.parse(request.referer.to_s).path
          return "sign_up" if referer_path == new_sign_app_up_path

          "sign_in"
        rescue URI::InvalidURIError
          "sign_in"
        end
      end
    end
  end
end
