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
        include CloudflareTurnstile
        include ::Verification::Client

        include SocialAuthConcern

        AUTHENTICATION_MODE = :deny_all
        rescue_from SocialAuth::BaseError, with: :handle_social_auth_error
        rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique

        SUPPORTED_PROVIDERS = %w(google_app apple).freeze
        SOCIAL_LINK_SCOPE = SocialAuthConcern::SOCIAL_LINK_SCOPE

        # Public access for continue (login intent doesn't require auth)
        # For link/step-up intents, auth is checked in prepare_social_auth_intent!
        declare_authentication_mode! :open, only: :continue
        declare_authentication_mode! :private, only: %i(destroy)
        before_action :require_social_link_step_up!, only: :continue
        before_action :authorize_social_unlink!, only: :destroy

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
              new_sign_app_sign_in_path,
              alert: I18n.t("sign.app.social.sessions.invalid_provider"),
            )
          end

          # Prepare session with intent context (OmniAuth manages OAuth state)
          state = prepare_social_auth_intent!(
            intent,
            provider: provider,
            pt: signed_pt_token(resolved_path_or_navigation_target),
            entry: social_auth_entry,
            ri: params[:ri].presence,
          )
          if params[:social_ceremony_grant].present?
            store_social_ceremony_grant!(params[:social_ceremony_grant])
          elsif intent.to_s == "login"
            issuance = Identity::SocialCeremony::GrantIssuer.issue!(
              surface: "app",
              actor_ref: social_login_actor_ref,
              session_ref: state,
              operation: "login",
              provider: provider,
              resource_ref: social_auth_entry,
              return_to: path_from_signed_pt(signed_pt_token(resolved_path_or_navigation_target)),
            )
            store_social_ceremony_grant!(issuance.grant)
          end
          issue_sign_up_flow!(provider) if social_auth_entry == "sign_up"

          safe_redirect_to(
            omniauth_authorize_path(provider, state: state),
            fallback: new_sign_app_sign_in_path,
          )
        rescue SocialAuth::BaseError => e
          handle_social_auth_error(e)
        end

        # DELETE /social/auth/:provider
        # Removes a linked social identity from current user.
        def destroy
          provider = params[:provider]

          return redirect_social_unlink_turnstile_failure unless cloudflare_turnstile_stealth_validation["success"]

          SocialAuthService.unlink(provider: provider, client: current_client)
          redirect_to(
            social_unlink_success_path(provider),
            notice: I18n.t(
              "sign.app.social.sessions.unlink.success",
              provider: SocialIdentifiable.normalize_provider(provider).humanize,
            ),
            status: :see_other,
          )
        rescue SocialAuth::LastIdentityError => e
          redirect_to(
            social_unlink_failure_path(provider),
            alert: I18n.t(e.message),
            status: :see_other,
          )
        rescue SocialAuth::BaseError => e
          render plain: I18n.t(e.message), status: e.status_code
        end

        private

        def social_auth_entry
          return "sign_up" if request.parameters["entry"].to_s == "sign_up"

          referer_path = URI.parse(request.referer.to_s).path
          return "sign_up" if referer_path == new_sign_app_sign_up_path

          "sign_in"
        rescue URI::InvalidURIError
          "sign_in"
        end

        def issue_sign_up_flow!(provider)
          cycle =
            AppTicketRecord.connected_to(role: :writing) do
              ClientSignUpFlowStatus.ensure_defaults!
              ClientSignUpFlow.create!(
                principal_id: nil,
                status_id: ClientSignUpFlowStatus::STARTED,
                step: "start",
                nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
                issued_at: Time.current,
                expires_at: ClientSignUpFlow.default_ttl.from_now,
                entry_method: social_entry_method(provider),
                social_provider: social_entry_method(provider),
                return_to: resolved_path_or_navigation_target,
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

          sign_up_flow_locator.issue!(cycle)
          session[:sign_app_up_sequence_id] = cycle.public_id
        end

        def social_login_actor_ref
          "anonymous"
        end

        def social_entry_method(provider)
          SocialIdentifiable.normalize_provider(provider)
        end

        def authorize_social_unlink!
          identity = social_identity_for_provider(params[:provider])
          if identity.present?
            authorize!(identity, to: :destroy?)
          else
            authorize!(current_client, to: :update?)
          end
        end

        def social_identity_for_provider(provider)
          case SocialIdentifiable.normalize_provider(provider)
          when "apple"
            current_client.user_apple_identity
          when "google"
            current_client.user_google_identity
          end
        end

        def redirect_social_unlink_turnstile_failure
          redirect_to(
            social_unlink_failure_path(params[:provider]),
            alert: t("turnstile_error"),
            status: :see_other,
          )
        end

        def social_unlink_success_path(provider)
          social_unlink_settings_path(provider)
        end

        def social_unlink_failure_path(provider)
          social_unlink_settings_path(provider)
        end

        def social_unlink_settings_path(provider)
          case SocialIdentifiable.normalize_provider(provider)
          when "apple"
            sign_app_settings_apple_path(ri: params[:ri])
          else
            sign_app_settings_google_path(ri: params[:ri])
          end
        end

        def require_social_link_step_up!
          return true unless params[:intent].to_s == "link"
          return true unless SUPPORTED_PROVIDERS.include?(params[:provider].to_s)
          return true unless logged_in? && current_resource.present?
          return true if step_up_satisfied?(scope: SOCIAL_LINK_SCOPE)

          flash[:alert] = I18n.t("auth.step_up.required")
          redirect_to(
            actor_verification_path(
              scope: SOCIAL_LINK_SCOPE,
              pt: encoded_relative_pt(social_link_settings_path(params[:provider])),
              ri: params[:ri],
            ),
            status: :see_other,
          )
          false
        end

        def social_link_settings_path(provider)
          case SocialIdentifiable.normalize_provider(provider)
          when "apple"
            sign_app_settings_apple_path(ri: params[:ri])
          else
            sign_app_settings_google_path(ri: params[:ri])
          end
        end

        def safe_decoded_rt(encoded_url)
          token = signed_pt_token(encoded_url)
          path_from_signed_pt(token)
        end

        def sign_up_flow_locator
          SignUp::CycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow)
        end

        def verification_required_action?
          action_name == "destroy"
        end

        def verification_scope
          "social_unlink"
        end
      end
    end
  end
end
