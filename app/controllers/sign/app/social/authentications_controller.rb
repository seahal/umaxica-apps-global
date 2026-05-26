# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Social
      # Controller for social auth entry points and account management
      #
      # Routes:
      #   POST   /social/auth/:provider/continue -> #continue (default continue entry point)
      #   DELETE /social/auth/:provider       -> #destroy (remove linked identity)
      #
      # The actual OmniAuth callbacks are handled by:
      #   Sign::App::Auth::OmniauthCallbacksController
      class AuthenticationsController < Sign::App::ApplicationController
        include ::Verification::Client

        include ::CloudflareTurnstile

        include SocialAuthConcern

        AUTHENTICATION_MODE = :deny_all

        SUPPORTED_PROVIDERS = %w(google_app apple).freeze
        SOCIAL_UNLINK_SCOPE = "social_unlink"

        # Public access for continue (login intent doesn't require auth)
        # For link/step-up intents, auth is checked in prepare_social_auth_intent!
        declare_authentication_mode! :open, only: :continue
        declare_authentication_mode! :private, only: %i(destroy)
        before_action :require_social_unlink_step_up!, only: :destroy
        before_action :require_social_unlink_turnstile!, only: :destroy

        # POST /social/auth/:provider/continue
        # Entry point for social auth flow from sign-up and sign-in screens.
        # Prepares session with intent/state, then redirects to OmniAuth.
        #
        # Params:
        #   - provider: "google_app" or "apple"
        #   - intent: "login", "link", or "step_up" (default: "login")
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
            pt: signed_pt_token(path_target_value),
            entry: social_auth_entry,
            ri: params[:ri].presence,
          )
          issue_sign_up_cycle!(provider) if social_auth_entry == "sign_up"

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
            SocialAuthService.unlink(provider: provider, client: current_resource)
          end

          redirect_to(
            sign_app_configuration_path,
            notice: I18n.t(
              "sign.app.social.sessions.unlink.success",
              provider: normalized_provider.humanize,
            ),
          )
        rescue SocialAuth::BaseError => e
          render plain: e.message, status: e.status_code
        end

        private

        def social_auth_entry
          return "sign_up" if request.parameters["entry"].to_s == "sign_up"

          referer_path = URI.parse(request.referer.to_s).path
          return "sign_up" if referer_path == new_sign_app_up_path

          "sign_in"
        rescue URI::InvalidURIError
          "sign_in"
        end

        def issue_sign_up_cycle!(provider)
          cycle =
            AppTicketRecord.connected_to(role: :writing) do
              ClientSignUpCycleStatus.ensure_defaults!
              ClientSignUpCycle.create!(
                principal_id: nil,
                status_id: ClientSignUpCycleStatus::STARTED,
                step: "start",
                nonce_digest: ClientSignUpCycle.digest_nonce(SecureRandom.urlsafe_base64(32)),
                issued_at: Time.current,
                expires_at: ClientSignUpCycle.default_ttl.from_now,
                entry_method: social_entry_method(provider),
                social_provider: social_entry_method(provider),
                pt: safe_decoded_rt(path_target_value),
              )
            end
          result =
            AppTicketRecord.connected_to(role: :writing) do
              SignUp::StateMachine.call(
                ticket: cycle,
                event: :start_social_callback,
                actor_context: Actor.authn,
              )
            end
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless result.status == :advanced

          sign_up_cycle_locator.issue!(cycle)
          session[:sign_app_up_sequence_id] = cycle.public_id
        end

        def social_entry_method(provider)
          SocialIdentifiable.normalize_provider(provider)
        end

        def require_social_unlink_step_up!
          return true if step_up_satisfied?(scope: SOCIAL_UNLINK_SCOPE)

          flash[:alert] = I18n.t("auth.step_up.required")
          redirect_to(
            actor_verification_path(
              scope: SOCIAL_UNLINK_SCOPE,
              pt: encoded_relative_pt(social_unlink_configuration_path(params[:provider])),
              ri: params[:ri],
            ),
            status: :see_other,
          )
          false
        end

        def require_social_unlink_turnstile!
          return true if cloudflare_turnstile_stealth_validation["success"]

          redirect_to(
            social_unlink_configuration_path(params[:provider]),
            alert: I18n.t("turnstile_error"),
            status: :see_other,
          )
          false
        end

        def social_unlink_configuration_path(provider)
          case SocialIdentifiable.normalize_provider(provider)
          when "apple"
            sign_app_configuration_apple_path(ri: params[:ri])
          else
            sign_app_configuration_google_path(ri: params[:ri])
          end
        end

        def safe_decoded_rt(encoded_url)
          token = signed_pt_token(encoded_url)
          path_from_signed_pt(token)
        end

        def sign_up_cycle_locator
          SignUp::CycleLocator.new(session, surface: :app, cycle_class: ClientSignUpCycle)
        end
      end
    end
  end
end
