# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Social
      class AuthenticationsController < Acme::App::ApplicationController
        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        protect_from_forgery with: :null_session, only: :completion

        def completion
          provider = social_provider_param
          result_token = params.require(:social_ceremony_result)
          commit = Identity::SocialCeremony::FinalCommitter.call!(
            result_token: result_token,
            actor: nil,
            session_ref: social_result_session_ref(result_token),
            surface: "app",
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
          )
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless commit.user

          return complete_social_signup!(commit, provider) if social_sign_up_required?(commit)

          complete_social_login!(commit, provider)
        rescue Identity::SocialCeremony::Error, ActionController::ParameterMissing
          redirect_to(
            new_sign_app_sign_in_url(ri: params[:ri], host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost")),
            alert: I18n.t("sign.app.social.sessions.create.failure"),
            allow_other_host: true,
          )
        rescue SocialAuth::BaseError => e
          redirect_to(
            new_sign_app_sign_in_url(ri: params[:ri], host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost")),
            alert: I18n.t(e.message),
            allow_other_host: true,
          )
        end

        private

        def complete_social_login!(commit, provider)
          result = establish_signed_in_session!(
            commit.user,
            pt: commit.pt,
            ri: params[:ri],
            auth_method: "social",
            audit_context: { auth_method: "social", provider: SocialIdentifiable.normalize_provider(provider) },
          )
          sign_in_result = sign_in_result_from_session_result(result, actor: commit.user)

          if sign_in_result.status == :success || sign_in_result.status == :session_limit_pending
            return redirect_to(
              sign_in_result.redirect_to,
              notice: I18n.t(
                "sign.app.social.sessions.create.already_registered",
                provider: SocialIdentifiable.normalize_provider(provider).humanize,
              ),
              allow_other_host: after_login_allows_other_host?,
            )
          end

          handle_social_login_failure!(sign_in_result)
        end

        def complete_social_signup!(commit, provider)
          cycle = create_social_sign_up_flow!(commit)
          bind_social_sign_up_flow!(cycle, commit)
          redirect_to(
            sign_app_up_guardrail_url(
              ri: params[:ri],
              pt: signed_pt_token(commit.pt),
              host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
            ),
            notice: I18n.t(
              "sign.app.social.sessions.create.success",
              provider: SocialIdentifiable.normalize_provider(provider).humanize,
            ),
            allow_other_host: true,
          )
        end

        def handle_social_login_failure!(sign_in_result)
          if sign_in_result.status == :mfa_required
            return redirect_to(sign_in_result.redirect_to, notice: I18n.t("sign.app.in.mfa.required"))
          end

          redirect_to(
            new_sign_app_sign_in_url(ri: params[:ri], host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost")),
            alert: I18n.t("sign.app.social.sessions.create.failure"),
            allow_other_host: true,
          )
        end

        def social_sign_up_required?(commit)
          !commit.existing_account || commit.user&.birthdate.blank?
        end

        def create_social_sign_up_flow!(commit)
          AppTicketRecord.connected_to(role: :writing) do
            ClientSignUpFlowStatus.ensure_defaults!
            ClientSignUpFlow.create!(
              principal_id: nil,
              status_id: ClientSignUpFlowStatus::SOCIAL_CALLBACK_PENDING,
              step: "social_callback",
              nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
              issued_at: Time.current,
              expires_at: ClientSignUpFlow.default_ttl.from_now,
              entry_method: SocialIdentifiable.normalize_provider(commit.identity.provider),
              social_provider: SocialIdentifiable.normalize_provider(commit.identity.provider),
              return_to: safe_social_return_to(commit.pt),
            )
          end
        end

        def bind_social_sign_up_flow!(cycle, commit)
          identity = commit.identity
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless identity&.persisted?
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless identity.user_id ==
            commit.user.id

          AppTicketRecord.connected_to(role: :writing) do
            cycle.update!(
              principal_id: commit.user.id,
              pending_contact_type: "social_identity",
              pending_contact_id: identity.id,
              social_provider: SocialIdentifiable.normalize_provider(identity.provider),
            )
            result = SignUp::StateMachine.call(
              ticket: cycle,
              event: :complete_social_callback,
              actor_context: Actor.authn,
            )
            raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless result.status == :advanced
          end
          SignUp::CycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow).issue!(cycle)
          session[:sign_app_up_sequence_id] = cycle.public_id
        end

        def social_result_session_ref(result_token)
          Identity::SocialCeremony::Contract.decode_unverified_payload(result_token).fetch("session_ref")
        end

        def social_provider_param
          provider = params[:provider].to_s
          return provider if Identity::SocialCeremony::Contract::PROVIDERS.include?(provider)

          raise ActionController::BadRequest, "invalid social provider"
        end

        def safe_social_return_to(value)
          path_from_signed_pt(signed_pt_token(value))
        end
      end
    end
  end
end
