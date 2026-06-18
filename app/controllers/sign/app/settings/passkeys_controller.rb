# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      # PasskeysController handles Passkey registration and management for users.
      #
      # Registration Flow:
      # 1. User visits /settings/passkeys/new
      # 2. POST /settings/passkeys/options to get WebAuthn challenge
      # 3. Browser performs navigator.credentials.create()
      # 4. POST /settings/passkeys/verification with credential + challenge_id
      # 5. sign/id verifies the ceremony; acme/www commits the passkey binding
      #
      # CRUD operations:
      # - GET /settings/passkeys (index)
      # - GET /settings/passkeys/:id (show)
      # - GET /settings/passkeys/:id/edit (edit)
      # - PATCH /settings/passkeys/:id (update - description only)
      # - DELETE /settings/passkeys/:id (destroy)
      class PasskeysController < ::Sign::App::ApplicationController
        include ::VerificationClient

        include SignWebauthn
        include SignPasskeyCeremonyDelegation
        include ::SignRequiresRecoveryPasscodes

        include ::CloudflareTurnstile
        include ::SignAcmeAuthorityRedirect

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        step_up only: %i(new create options verification), bootstrap: true
        before_action :require_recovery_passcodes_for_mfa_registration!, only: %i(new create options verification)
        before_action :accept_app_passkey_ceremony_grant!, only: %i(new options verification)
        before_action :set_passkey, only: []
        before_action :verify_settings_passkey_turnstile!, only: :options

        # GET /settings/passkeys
        def index
          redirect_to_acme_settings_authority!
        end

        # GET /settings/passkeys/:id
        def show
          redirect_to_acme_settings_authority!
        end

        # GET /settings/passkeys/new
        def new
          @passkey = current_client.client_passkeys.new
          start_passkey_ceremony!(_surface: "app", _actor: current_client, _session_ref: current_session_public_id)
        end

        # GET /settings/passkeys/:id/edit
        def edit
          redirect_to_acme_settings_authority!
        end

        # POST /settings/passkeys
        def create
          @passkey = current_client.client_passkeys.new(description: passkey_description)
          authorize!(@passkey)

          respond_to do |format|
            format.html do
              redirect_to(
                new_sign_app_settings_passkey_path(ri: params[:ri]),
                status: :see_other,
                alert: passkey_verification_required_message,
              )
            end
            format.json do
              render json: { error: passkey_verification_required_message },
                     status: :unprocessable_content
            end
          end
        end

        # POST /settings/passkeys/options
        # Generate WebAuthn registration options
        #
        # Response:
        #   {
        #     challenge_id: "abc123",
        #     options: { ... WebAuthn options ... }
        #   }
        def options
          # Build exclude list from existing passkeys
          existing_credentials =
            current_client.client_passkeys.map do |passkey|
              { id: passkey.webauthn_id }
            end

          challenge_id, creation_options = create_registration_challenge(
            resource: current_client,
            exclude_credentials: existing_credentials,
          )

          render json: {
            challenge_id: challenge_id,
            options: creation_options,
          }, status: :ok
        rescue SignWebauthn::OriginValidationError => e
          Rails.logger.error(
            JitLogEvent.format(
              "sign.webauthn.registration.origin_validation_failed", message: e.message,
                                                                     exception: e,
            ),
          )
          render json: { error: I18n.t("errors.webauthn.origin_invalid") }, status: :forbidden
        rescue SignWebauthn::ChallengeError, WebAuthn::Error, ArgumentError => e
          Rails.logger.error(
            JitLogEvent.format(
              "sign.webauthn.registration.options_failed", message: e.message,
                                                           exception: e,
            ),
          )
          render json: { error: I18n.t("errors.webauthn.options_failed") }, status: :unprocessable_content
        end

        # POST /settings/passkeys/verification
        # Verify WebAuthn registration response and emit an acme-owned commit result.
        #
        # Request body:
        #   {
        #     challenge_id: "abc123",
        #     credential: { id: "...", response: { ... }, ... },
        #     description: "My MacBook" (optional)
        #   }
        #
        # Response on success:
        #   {
        #     status: "ok",
        #     redirect_url: "/settings/passkeys"
        #   }
        def verification
          challenge_id = params[:challenge_id]
          return render_missing_challenge_id if challenge_id.blank?

          with_challenge(challenge_id, purpose: :registration) do |challenge|
            credential = build_registration_credential
            verify_registration_credential!(credential, challenge)

            passkey = commit_passkey_ceremony!(credential, challenge_id)

            render_verification_success(passkey)
          end
        rescue SignWebauthn::ChallengeNotFoundError,
               SignWebauthn::ChallengeExpiredError => e
          Rails.logger.warn(JitLogEvent.format("sign.webauthn.registration.challenge_error", message: e.message))
          render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
        rescue SignWebauthn::ChallengePurposeMismatchError => e
          Rails.logger.warn(
            JitLogEvent.format(
              "sign.webauthn.registration.challenge_purpose_mismatch",
              message: e.message,
            ),
          )
          render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
        rescue WebAuthn::Error => e
          Rails.logger.warn(JitLogEvent.format("sign.webauthn.registration.failed", message: e.message))
          render json: { error: I18n.t("errors.webauthn.verification_failed") },
                 status: :unprocessable_content
        rescue IdentityPasskeyCeremonyContract::Error => e
          Rails.logger.warn(JitLogEvent.format("sign.webauthn.registration.commit_failed", message: e.message))
          render json: { error: I18n.t("errors.webauthn.verification_failed") },
                 status: :unprocessable_content
        rescue ActiveRecord::RecordNotUnique
          render json: { error: I18n.t("errors.webauthn.credential_already_registered") }, status: :conflict
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn(JitLogEvent.format("sign.webauthn.registration.persist_failed", message: e.message))
          render plain: e.record.errors.full_messages.join("\n"), status: :unprocessable_content
        end

        # PATCH/PUT /settings/passkeys/:id
        def update
          redirect_to_acme_settings_authority!
        end

        # DELETE /settings/passkeys/:id
        def destroy
          redirect_to_acme_settings_authority!
        end

        private

        def verify_settings_passkey_turnstile!
          return true if cloudflare_turnstile_stealth_validation["success"]

          respond_to do |format|
            format.html do
              redirect_back_or_to(
                sign_app_settings_passkeys_path(ri: params[:ri]), alert: t("turnstile_error"),
                                                                  status: :see_other,
              )
            end
            format.json { render json: { error: t("turnstile_error") }, status: :unprocessable_content }
          end
          false
        end

        def accept_app_passkey_ceremony_grant!
          return true if accept_passkey_ceremony_grant!(surface: "app")

          respond_to do |format|
            format.html do
              redirect_to(
                acme_app_settings_passkeys_path(ri: params[:ri]),
                alert: I18n.t("errors.messages.invalid"),
                status: :see_other,
              )
            end
            format.json { render json: { error: I18n.t("errors.messages.invalid") }, status: :bad_request }
          end
          false
        end

        def set_passkey
          @passkey = current_client.client_passkeys.find_by!(public_id: params(:id))
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

        def render_missing_challenge_id
          render json: {
            error: I18n.t("errors.webauthn.challenge_id_required"),
          }, status: :bad_request
        end

        def build_registration_credential
          WebAuthn::Credential.from_create(credential_params.to_h, relying_party: webauthn_relying_party)
        end

        def verify_registration_credential!(credential, challenge)
          credential.verify(challenge)
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
            surface: "app",
            actor: current_client,
            session_ref: current_session_public_id,
            candidate: candidate,
            challenge_id: challenge_id,
          )
          reset_passkey_ceremony_session!
          commit.passkey
        end

        def render_verification_success(passkey)
          default_redirect_url = acme_app_settings_passkeys_url(
            ri: params[:ri],
            host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
          )
          redirect_url = bootstrap_return_path(default_redirect_url)

          render json: {
            status: "ok",
            passkey_id: passkey.id,
            redirect_url: redirect_url,
          }, status: :created
        end

        def update_params
          key = %i(client_passkey user_passkey passkey).find { |candidate| params.key?(candidate) }
          return {} unless key

          params.fetch(key, {}).permit(:description)
        end

        def create_params
          params.fetch(:user_passkey, {}).permit(:description)
        end

        def passkey_verification_required_message
          I18n.t("errors.webauthn.verification_required")
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

        def recovery_passcode_requirement_actor
          current_client
        end

        def recovery_passcode_requirement_credential_class
          ClientSecretCredential
        end

        def recovery_passcode_setup_url
          acme_app_settings_secrets_url(
            ri: params[:ri],
            host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
          )
        end

        # Compatibility entry only. acme/www owns account-facing passkey lifecycle.
        def redirect_to_acme_settings_authority!
          redirect_to_acme_authority!(request.path, query: request.query_parameters)
        end
      end
    end
  end
end
