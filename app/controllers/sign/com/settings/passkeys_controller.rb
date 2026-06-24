# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      class PasskeysController < ::Sign::Com::ApplicationController
        include ::VerificationVisitor

        include SignWebauthn
        include SignSettingsPasskeyRegistration
        include ::SignRequiresRecoveryPasscodes

        include ::CloudflareTurnstile
        include ::SignAuthorityRedirect

        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
        # Object-level authorization (ActionPolicy): index/create gate the actor type; show/edit/
        # update/destroy authorize the owned record (set_passkey is owner-scoped -> 404 first).
        # Step-up / Turnstile / WebAuthn-challenge guards remain in place for the registration ceremony.
        before_action :authorize_passkeys!, only: %i(index)
        before_action :authorize_passkey_create!, only: %i(create)
        step_up only: %i(new create options verification), bootstrap: true
        before_action :require_recovery_passcodes_for_mfa_registration!, only: %i(new create options verification)
        before_action :set_passkey, only: %i(show edit update destroy)
        before_action :verify_settings_passkey_turnstile!, only: :options

        def index
          @passkeys = current_visitor.visitor_passkeys.order(created_at: :asc)
        end

        def show
          authorize!(@passkey)
        end

        def new
          @passkey = current_visitor.visitor_passkeys.new
          start_passkey_ceremony!(surface: "com", actor: current_visitor, session_ref: current_session_public_id)
        end

        def edit
          authorize!(@passkey)
        end

        def create
          respond_to do |format|
            format.html do
              redirect_to(
                new_sign_com_settings_passkey_path(ri: params[:ri]),
                status: :see_other,
              )
            end
            format.json do
              render json: {
                status: "registration_ceremony_required",
                redirect_path: new_sign_com_settings_passkey_path(ri: params[:ri]),
              }, status: :accepted
            end
          end
        end

        def options
          existing_credentials = current_visitor.visitor_passkeys.map { |passkey| { id: passkey.webauthn_id } }
          challenge_id, creation_options = create_registration_challenge(
            resource: current_visitor,
            exclude_credentials: existing_credentials,
          )

          render json: {
            challenge_id: challenge_id,
            options: creation_options,
          }, status: :ok
        rescue SignWebauthn::OriginValidationError => e
          Rails.logger.error(JitLogEvent.format("webauthn.origin_validation_failed", message: e.message))
          render json: { error: I18n.t("errors.webauthn.origin_invalid") }, status: :forbidden
        rescue SignWebauthn::ChallengeError, WebAuthn::Error, ArgumentError => e
          Rails.logger.error(
            JitLogEvent.format(
              "webauthn.registration_options_failed", error_class: e.class.name,
                                                      message: e.message,
            ),
          )
          render json: { error: I18n.t("errors.webauthn.options_failed") }, status: :unprocessable_content
        end

        def verification
          challenge_id = params[:challenge_id]
          if challenge_id.blank?
            return render json: {
              error: I18n.t("errors.webauthn.challenge_id_required"),
            }, status: :bad_request
          end

          render_verification_result(perform_webauthn_registration!(challenge_id))
        rescue SignWebauthn::ChallengeNotFoundError,
               SignWebauthn::ChallengeExpiredError => e
          Rails.logger.warn("WebAuthn challenge error: #{e.message}")
          render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
        rescue SignWebauthn::ChallengePurposeMismatchError => e
          Rails.logger.warn("WebAuthn challenge purpose mismatch: #{e.message}")
          render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
        rescue WebAuthn::Error => e
          Rails.logger.warn("WebAuthn registration failed: #{e.message}")
          render json: { error: I18n.t("errors.webauthn.verification_failed") },
                 status: :unprocessable_content
        rescue IdentityPasskeyCeremonyContract::Error => e
          Rails.logger.warn("WebAuthn passkey commit failed: #{e.message}")
          render json: { error: I18n.t("errors.webauthn.verification_failed") },
                 status: :unprocessable_content
        rescue ActiveRecord::RecordNotUnique
          render json: { error: I18n.t("errors.webauthn.credential_already_registered") }, status: :conflict
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn("WebAuthn passkey creation failed: #{e.message}")
          render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
        end

        def update
          authorize!(@passkey)

          if @passkey.update(update_params)
            redirect_to(sign_com_settings_passkey_path(@passkey.public_id, ri: params[:ri]), status: :see_other)
          else
            render :edit, status: :unprocessable_content
          end
        end

        def destroy
          authorize!(@passkey)
          unless AuthMethodGuard.can_remove_passkey?(current_visitor, @passkey)
            redirect_to(
              sign_com_settings_passkeys_path(ri: params[:ri]),
              alert: t("messages.cannot_delete_last_passkey"),
              status: :see_other,
            )
            return
          end
          @passkey.destroy!
          redirect_to(sign_com_settings_passkeys_path(ri: params[:ri]), status: :see_other)
        end

        private

        def authorize_passkeys!
          authorize!(VisitorPasskey, to: :index?)
        end

        def authorize_passkey_create!
          authorize!(VisitorPasskey, to: :create?)
        end

        def verify_settings_passkey_turnstile!
          return true if cloudflare_turnstile_stealth_validation["success"]

          respond_to do |format|
            format.html do
              redirect_back_or_to(
                sign_com_settings_passkeys_path(ri: params[:ri]), alert: t("turnstile_error"),
                                                                  status: :see_other,
              )
            end
            format.json { render json: { error: t("turnstile_error") }, status: :unprocessable_content }
          end
          false
        end

        def set_passkey
          @passkey = current_visitor.visitor_passkeys.find_by!(public_id: params.expect(:id))
        end

        def perform_webauthn_registration!(challenge_id)
          with_challenge(challenge_id, purpose: :registration) do |challenge|
            credential = WebAuthn::Credential.from_create(
              credential_params.to_h,
              relying_party: webauthn_relying_party,
            )
            credential.verify(challenge)
            passkey = commit_passkey_ceremony!(credential, challenge_id)
            { passkey: passkey, challenge_id: challenge_id }
          end
        end

        def render_verification_result(result)
          passkey = result[:passkey]
          render json: {
            status: "ok",
            passkey_id: passkey.id,
            redirect_url: bootstrap_return_path(
              sign_com_settings_passkeys_url(
                ri: params[:ri],
                host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"),
              ),
            ),
          }, status: :created
        end

        def credential_params
          params.fetch(:credential, {}).permit(
            :id,
            :rawId,
            :type,
            :authenticatorAttachment,
            { transports: [] },
            { response: %i(clientDataJSON attestationObject) },
            { clientExtensionResults: {} },
          )
        end

        def update_params
          key = params.key?(:visitor_passkey) ? :visitor_passkey : :passkey
          params.fetch(key, {}).permit(:description)
        end

        def commit_passkey_ceremony!(credential, challenge_id)
          candidate = IdentityPasskeyCeremonyResultIssuer::Candidate.new(
            webauthn_id: credential.id,
            public_key: credential.public_key,
            sign_count: credential.sign_count,
            description: passkey_description,
            transports: credential_params[:transports],
          )
          commit = finish_passkey_ceremony!(
            surface: "com",
            actor: current_visitor,
            session_ref: current_session_public_id,
            candidate: candidate,
            challenge_id: challenge_id,
          )
          reset_passkey_ceremony_session!
          commit.passkey
        end

        def passkey_description
          params[:description].presence || I18n.t("sign.default_passkey_description")
        end

        def verification_required_action?
          step_up_bootstrap_active? && %w(new create options verification).include?(action_name)
        end

        def verification_scope
          "settings_passkey"
        end

        def recovery_passcode_requirement_active_strong_credential_count
          current_visitor.visitor_passkeys.active.count
        end

        def recovery_passcode_requirement_actor
          current_visitor
        end

        def recovery_passcode_requirement_credential_class
          VisitorSecretCredential
        end

        def recovery_passcode_setup_url
          sign_com_settings_secret_credentials_url(
            ri: params[:ri],
            host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"),
          )
        end
      end
    end
  end
end
