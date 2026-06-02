# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Social
      # Controller for operators social auth entry point.
      #
      # Routes:
      #   POST /social/auth/:provider/continue -> #continue
      #   DELETE /social/auth/:provider         -> #destroy
      #
      # Operator social continue signs in existing staff only; unknown staff are not created.
      class AuthenticationsController < Sign::Org::ApplicationController
        include SocialAuthConcern

        include ::Verification::Operator

        AUTHENTICATION_MODE = :deny_all
        rescue_from SocialAuth::BaseError, with: :handle_social_auth_error
        rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique

        SUPPORTED_PROVIDERS = %w(google_org).freeze

        declare_authentication_mode! :open, only: %i(continue signup)
        declare_authentication_mode! :private, only: :destroy
        step_up only: :destroy, scope: "social_unlink"

        # POST /social/auth/:provider/continue
        # Prepares intent/state in session, then redirects to OmniAuth provider.
        def continue
          provider = params[:provider]

          unless SUPPORTED_PROVIDERS.include?(provider)
            return redirect_to(
              new_sign_org_sign_in_path,
              alert: I18n.t("sign.org.social.sessions.invalid_provider"),
            )
          end
          return redirect_google_signin_disabled unless google_signin_enabled?

          state = prepare_social_auth_intent!("login", provider: provider)

          safe_redirect_to(
            omniauth_authorize_path(provider, state: state),
            fallback: new_sign_org_sign_in_path,
          )
        rescue SocialAuth::BaseError => e
          handle_social_auth_error(e)
        end

        # TEMP(org-google-social-gateway): remove before production cleanup
        def signup
          provider = params[:provider]

          unless SUPPORTED_PROVIDERS.include?(provider)
            return redirect_to(
              new_sign_org_sign_up_path,
              alert: I18n.t("sign.org.social.sessions.invalid_provider"),
            )
          end
          return redirect_google_signup_disabled unless google_signup_enabled?

          state = prepare_social_auth_intent!("login", provider: provider, entry: "sign_up")

          safe_redirect_to(
            omniauth_authorize_path(provider, state: state),
            fallback: new_sign_org_sign_up_path,
          )
        rescue SocialAuth::BaseError => e
          handle_social_auth_error(e)
        end

        def destroy
          provider = params[:provider]
          unless SUPPORTED_PROVIDERS.include?(provider)
            return redirect_to(
              sign_org_configuration_path,
              alert: I18n.t("sign.org.social.sessions.invalid_provider"),
            )
          end

          unlink_google_org!
          redirect_to(
            sign_org_configuration_path(ri: params[:ri]),
            notice: I18n.t(
              "sign.app.social.sessions.unlink.success",
              provider: SocialIdentifiable.normalize_provider(provider).humanize,
            ),
          )
        end

        private

        def google_signin_enabled?
          Sign::Social::OrgGoogleSigninGate.enabled?
        end

        def redirect_google_signin_disabled
          redirect_to(
            new_sign_org_sign_in_path,
            alert: I18n.t("sign.org.social.sessions.create.failure"),
          )
        end

        def google_signup_enabled?
          Sign::Social::TemporarySignupGate.signup_enabled?
        end

        def redirect_google_signup_disabled
          redirect_to(
            new_sign_org_sign_up_path,
            alert: I18n.t("sign.org.social.sessions.create.failure"),
          )
        end

        def unlink_google_org!
          identity = current_operator.operator_google_identity
          authorize!(identity, with: OperatorIdentityPolicy) if identity.present?

          Operator.transaction do
            current_operator.lock!
            identity&.destroy!
            create_google_unlink_audit! if identity
          end
        end

        def create_google_unlink_audit!
          ChronicleRecord.connected_to(role: :writing) do
            OperatorChronicleEvent.find_or_create_by!(id: OperatorChronicleEvent::SOCIAL_UNLINKED)
            OperatorChronicleLevel.find_or_create_by!(id: OperatorChronicleLevel::NOTHING)
          end

          OperatorChronicle.create!(
            actor_type: "Operator",
            actor_id: current_operator.id,
            event_id: OperatorChronicleEvent::SOCIAL_UNLINKED,
            level_id: OperatorChronicleLevel::NOTHING,
            subject_id: current_operator.id.to_s,
            subject_type: "Operator",
            occurred_at: Time.current,
            context: {
              auth_method: "social",
              provider: "google",
            },
          )
        end

        def social_auth_failure_redirect_path
          new_sign_org_sign_in_path
        end
      end
    end
  end
end
