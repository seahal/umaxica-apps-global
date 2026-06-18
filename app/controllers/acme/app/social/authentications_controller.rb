# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Social
      class AuthenticationsController < Acme::App::ApplicationController
        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        def continue
          provider = social_provider_param
          issuance = IdentitySocialCeremonyGrantIssuer.issue!(
            surface: "app",
            actor_ref: "anonymous",
            session_ref: SecureRandom.hex(24),
            operation: "login",
            provider: provider,
            resource_ref: social_entry_param,
            return_to: safe_social_return_to(params[:pt].presence),
          )

          redirect_to(
            social_connection_url_for(
              provider,
              intent: "login",
              entry: social_entry_param,
              ri: params[:ri],
              social_ceremony_grant: issuance.grant,
              host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
            ),
            status: :see_other,
            allow_other_host: cross_host_redirect_allowed?,
          )
        end

        def completion
          provider = social_provider_param
          result_token = params.require(:social_ceremony_result)
          # The payload here is UNVERIFIED/untrusted. We read `operation` only to
          # fail-safe REJECT link completions on this login-only acme path. The
          # actual trust decision happens in IdentitySocialCeremonyFinalCommitter
          # below, which re-derives `operation` from the cryptographically
          # verified result, so tampering this value cannot grant anything.
          payload = IdentitySocialCeremonyContract.decode_untrusted_routing_payload(result_token)
          return reject_social_link_completion!(provider) if payload["operation"].to_s == "link"

          commit = IdentitySocialCeremonyFinalCommitter.call!(
            result_token: result_token,
            actor: nil,
            session_ref: social_result_session_ref(result_token),
            surface: "app",
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
          )
          raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless commit.user

          return complete_social_signup!(commit, provider) if commit.result["operation"].to_s != "signup" &&
            social_sign_up_required?(commit)

          complete_social_login!(commit, provider)
        rescue IdentitySocialCeremonyContract::Error, ActionController::ParameterMissing, ActiveRecord::RecordNotFound
          redirect_to(
            sign_app_sign_in_url(ri: params[:ri], host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost")),
            alert: I18n.t("sign.app.social.sessions.create.failure"),
            allow_other_host: cross_host_redirect_allowed?,
          )
        rescue SocialAuth::BaseError => e
          redirect_to(
            sign_app_sign_in_url(ri: params[:ri], host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost")),
            alert: I18n.t(e.message),
            allow_other_host: cross_host_redirect_allowed?,
          )
        end

        private

        # The sign/id callback renders a cross-origin auto-submit form. Some
        # browser/referrer-policy combinations send Origin: null for that POST,
        # which Rails rejects before trusted_origins can apply. The one-shot
        # signed ceremony result is the CSRF proof for this endpoint; acme still
        # verifies and consumes it in the action before creating a session.
        def verified_request?
          social_completion_result_verifies_request? || super
        end

        def social_completion_result_verifies_request?
          return false unless action_name == "completion"

          provider = social_provider_param
          result = IdentitySocialCeremonyResult.decode(
            params[:social_ceremony_result].to_s,
            issuer_id: IdentitySocialCeremonyContract.sign_issuer_id("app"),
          )

          result["surface"].to_s == "app" && result["provider"].to_s == provider
        rescue ActionController::BadRequest, IdentitySocialCeremonyContract::Error
          false
        end

        def reject_social_link_completion!(provider)
          redirect_to(
            sign_social_settings_url_for(provider),
            alert: I18n.t("sign.app.social.sessions.create.failure"),
            allow_other_host: cross_host_redirect_allowed?,
            status: :see_other,
          )
        end

        def sign_social_settings_url_for(provider)
          if SocialIdentifiable.normalize_provider(provider) == "apple"
            sign_app_settings_apple_url(ri: params[:ri], host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))
          else
            sign_app_settings_google_url(ri: params[:ri], host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))
          end
        end

        def complete_social_login!(commit, provider)
          # Social login reuses the same graph-provisioning boundary as
          # sign-up finalization. The final durable state is still written
          # through the app-side selector bootstrap after provider proof.
          IdentityGraphProvisioner.call!(surface: :app, principal: commit.user)
          result = establish_signed_in_session!(
            commit.user,
            pt: commit.pt,
            ri: params[:ri],
            auth_method: "social",
            audit_context: { auth_method: "social", provider: SocialIdentifiable.normalize_provider(provider) },
          )
          sign_in_result = sign_in_result_from_session_result(result, actor: commit.user)

          if sign_in_result.status == :success || sign_in_result.status == :session_limit_pending
            complete_acme_social_signup_flow!(commit, sign_in_result) if commit.result["operation"].to_s == "signup"
            return redirect_to(
              acme_social_login_redirect_to(sign_in_result),
              notice: I18n.t(
                "sign.app.social.sessions.create.already_registered",
                provider: SocialIdentifiable.normalize_provider(provider).humanize,
              ),
              allow_other_host: after_login_allows_other_host?,
            )
          end

          handle_social_login_failure!(sign_in_result)
        end

        def acme_social_login_redirect_to(sign_in_result)
          return acme_app_sign_settings_sessions_url(ri: params[:ri]) if sign_in_result.session_limit_pending?

          sign_in_result.redirect_to
        end

        def complete_social_signup!(commit, provider)
          cycle = create_social_sign_up_flow!(commit)
          bind_social_sign_up_flow!(cycle, commit)
          normalized_provider = SocialIdentifiable.normalize_provider(provider)
          redirect_to(
            public_send(
              :"sign_app_sign_up_guard_#{normalized_provider}_url",
              ri: params[:ri],
              pt: signed_pt_token(commit.pt),
              host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
            ),
            notice: I18n.t(
              "sign.app.social.sessions.create.success",
              provider: normalized_provider.humanize,
            ),
            allow_other_host: cross_host_redirect_allowed?,
          )
        end

        def handle_social_login_failure!(sign_in_result)
          if sign_in_result.status == :mfa_required
            return redirect_to(sign_in_result.redirect_to, notice: I18n.t("sign.app.in.mfa.required"))
          end

          redirect_to(
            sign_app_sign_in_url(ri: params[:ri], host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost")),
            alert: I18n.t("sign.app.social.sessions.create.failure"),
            allow_other_host: cross_host_redirect_allowed?,
          )
        end

        def social_sign_up_required?(commit)
          !commit.existing_account || commit.user&.birthdate.blank?
        end

        def complete_acme_social_signup_flow!(commit, sign_in_result)
          # Unknown social identities enter the sign-up cycle first, then
          # reuse the shared finalize/handoff/complete path once the
          # callback has been bound to the pending ticket.
          flow_id = commit.result["actor_ref"].to_s
          return if flow_id.blank?

          AppTicketRecord.connected_to(role: :writing) do
            cycle = ClientSignUpFlow.find_by!(public_id: flow_id)
            cycle.with_cycle_lock do
              cycle.reload
              cycle.update!(
                principal_id: commit.user.id,
                pending_contact_type: "social_identity",
                pending_contact_id: commit.identity.id,
                social_provider: SocialIdentifiable.normalize_provider(commit.identity.provider),
              )
              finalize = SignUpStateMachine.call(
                ticket: cycle,
                event: :finalize,
                actor_context: Actor.authn,
                payload: { finalization_result: :accepted },
              )
              raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless finalize.success?

              handoff = SignUpStateMachine.call(
                ticket: cycle,
                event: :handoff_to_sign_in,
                actor_context: Actor.authn,
                payload: {
                  sign_in_handoff_status: :accepted,
                  sign_in_handoff: sign_in_result.status,
                },
              )
              raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless handoff.success?

              complete = SignUpStateMachine.call(
                ticket: cycle,
                event: :complete,
                actor_context: Actor.authn,
              )
              raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless complete.success?
            end
          end
        end

        def create_social_sign_up_flow!(commit)
          # The callback only creates the pending sign-up ticket here; the
          # durable identity graph is still created later by the shared
          # sign-up finalize boundary.
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
            result = SignUpStateMachine.call(
              ticket: cycle,
              event: :complete_social_callback,
              actor_context: Actor.authn,
            )
            raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless result.status == :advanced
          end
          SignUpCycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow).issue!(cycle)
          session[:sign_app_up_sequence_id] = cycle.public_id
        end

        # Extracts `session_ref` from the UNVERIFIED payload purely so it can be
        # passed to IdentitySocialCeremonyFinalCommitter. The committer compares
        # it against the verified result["session_ref"] (mismatch => rejection),
        # so this untrusted value is a routing input, never a trust anchor.
        def social_result_session_ref(result_token)
          IdentitySocialCeremonyContract.decode_untrusted_routing_payload(result_token).fetch("session_ref")
        end

        def social_provider_param
          provider = params[:id].to_s
          return provider if IdentitySocialCeremonyContract::PROVIDERS.include?(provider)

          raise ActionController::BadRequest, "invalid social provider"
        end

        def social_entry_param
          (params[:entry].to_s == "sign_up") ? "sign_up" : "sign_in"
        end

        def safe_social_return_to(value)
          return nil if value.blank?

          path_from_signed_pt(signed_pt_token(value))
        end

        def social_connection_url_for(provider, **params)
          normalized_provider = SocialIdentifiable.normalize_provider(provider)
          public_send(:"sign_app_social_#{normalized_provider}_connection_url", **params)
        end
      end
    end
  end
end
