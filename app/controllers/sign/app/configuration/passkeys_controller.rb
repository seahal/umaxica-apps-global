# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      # PasskeysController handles Passkey registration and management for users.
      #
      # Registration Flow:
      # 1. User visits /configuration/passkeys/new
      # 2. POST /configuration/passkeys/options to get WebAuthn challenge
      # 3. Browser performs navigator.credentials.create()
      # 4. POST /configuration/passkeys/verification with credential + challenge_id
      # 5. Server verifies and creates ClientPasskey record
      #
      # CRUD operations:
      # - GET /configuration/passkeys (index)
      # - GET /configuration/passkeys/:id (show)
      # - GET /configuration/passkeys/:id/edit (edit)
      # - PATCH /configuration/passkeys/:id (update - description only)
      # - DELETE /configuration/passkeys/:id (destroy)
      class PasskeysController < Sign::App::ApplicationController
        include ::Verification::Client

        include Sign::Webauthn

        include ::CloudflareTurnstile

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        before_action only: %i(new create options verification) do
          require_step_up_unless_bootstrap!(scope: verification_scope)
        end
        before_action only: %i(edit update destroy) do
          require_step_up!(scope: verification_scope)
        end
        before_action :set_passkey, only: %i(show edit update destroy)
        before_action :verify_configuration_passkey_turnstile!, only: %i(options update destroy)

        # GET /configuration/passkeys
        def index
          @passkeys = authorized_scope(current_client.client_passkeys).order(created_at: :desc)
        end

        # GET /configuration/passkeys/:id
        def show
          authorize!(@passkey)
        end

        # GET /configuration/passkeys/new
        def new
          @passkey = current_client.client_passkeys.new
        end

        # GET /configuration/passkeys/:id/edit
        def edit
          authorize!(@passkey)
        end

        # POST /configuration/passkeys
        def create
          @passkey = current_client.client_passkeys.new(description: passkey_description)
          authorize!(@passkey)

          respond_to do |format|
            format.html do
              redirect_to(
                new_sign_app_configuration_passkey_path(ri: params[:ri]),
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

        # POST /configuration/passkeys/options
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
        rescue Sign::Webauthn::OriginValidationError => e
          Rails.logger.error(
            LogEvent.format(
              "sign.webauthn.registration.origin_validation_failed", message: e.message,
                                                                     exception: e,
            ),
          )
          render json: { error: I18n.t("errors.webauthn.origin_invalid") }, status: :forbidden
        rescue Sign::Webauthn::ChallengeError, WebAuthn::Error, ArgumentError => e
          Rails.logger.error(
            LogEvent.format(
              "sign.webauthn.registration.options_failed", message: e.message,
                                                           exception: e,
            ),
          )
          render json: { error: I18n.t("errors.webauthn.options_failed") }, status: :unprocessable_content
        end

        # POST /configuration/passkeys/verification
        # Verify WebAuthn registration response and create passkey
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
        #     redirect_url: "/configuration/passkeys"
        #   }
        def verification
          challenge_id = params[:challenge_id]
          return render_missing_challenge_id if challenge_id.blank?

          with_challenge(challenge_id, purpose: :registration) do |challenge|
            credential = build_registration_credential
            verify_registration_credential!(credential, challenge)

            passkey = build_passkey_from_credential(credential)
            persist_passkey!(passkey)

            issue_emergency_key_if_available!
            record_passkey_registration_step_up!
            render_verification_success
          end
        rescue Sign::Webauthn::ChallengeNotFoundError,
               Sign::Webauthn::ChallengeExpiredError => e
          Rails.logger.warn(LogEvent.format("sign.webauthn.registration.challenge_error", message: e.message))
          render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
        rescue Sign::Webauthn::ChallengePurposeMismatchError => e
          Rails.logger.warn(
            LogEvent.format(
              "sign.webauthn.registration.challenge_purpose_mismatch",
              message: e.message,
            ),
          )
          render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
        rescue WebAuthn::Error => e
          Rails.logger.warn(LogEvent.format("sign.webauthn.registration.failed", message: e.message))
          render json: { error: I18n.t("errors.webauthn.verification_failed") },
                 status: :unprocessable_content
        rescue ActiveRecord::RecordNotUnique
          render json: { error: I18n.t("errors.webauthn.credential_already_registered") }, status: :conflict
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn(LogEvent.format("sign.webauthn.registration.persist_failed", message: e.message))
          render plain: e.record.errors.full_messages.join("\n"), status: :unprocessable_content
        end

        # PATCH/PUT /configuration/passkeys/:id
        def update
          authorize!(@passkey)
          if @passkey.update(update_params)
            respond_to do |format|
              format.html do
                redirect_to(
                  sign_app_configuration_passkey_path(@passkey),
                  notice: t("messages.passkey_successfully_updated"),
                )
              end
              format.json { render json: { status: "ok" }, status: :ok }
            end
          else
            respond_to do |format|
              format.html { render :edit, status: :unprocessable_content }
              format.json {
                render json: { errors: @passkey.errors.full_messages }, status: :unprocessable_content
              }
            end
          end
        end

        # DELETE /configuration/passkeys/:id
        def destroy
          authorize!(@passkey)

          unless AuthMethodGuard.can_remove_passkey?(current_client, @passkey)
            respond_to do |format|
              format.html do
                redirect_to(
                  sign_app_configuration_passkeys_path,
                  status: :see_other,
                  alert: t("messages.cannot_delete_last_passkey"),
                )
              end
              format.json do
                render json: { error: t("messages.cannot_delete_last_passkey") },
                       status: :unprocessable_content
              end
            end
            return
          end

          @passkey.destroy!

          respond_to do |format|
            format.html do
              redirect_to(
                sign_app_configuration_passkeys_path,
                status: :see_other,
                notice: t("messages.passkey_successfully_destroyed"),
              )
            end
            format.json { head :no_content }
          end
        end

        private

        def verify_configuration_passkey_turnstile!
          return true if cloudflare_turnstile_stealth_validation["success"]

          respond_to do |format|
            format.html do
              redirect_back_or_to(
                sign_app_configuration_passkeys_path(ri: params[:ri]), alert: t("turnstile_error"),
                                                                       status: :see_other,
              )
            end
            format.json { render json: { error: t("turnstile_error") }, status: :unprocessable_content }
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

        def build_passkey_from_credential(credential)
          current_client.client_passkeys.new(
            webauthn_id: credential.id,
            public_key: credential.public_key,
            sign_count: credential.sign_count,
            description: passkey_description,
          )
        end

        def persist_passkey!(passkey)
          passkey.save!
        end

        def render_verification_success
          default_redirect_url =
            if emergency_key_reveal_token.present?
              sign_app_configuration_emergency_key_path(ri: params[:ri], token: emergency_key_reveal_token)
            else
              sign_app_configuration_passkeys_path(ri: params[:ri])
            end
          redirect_url = bootstrap_return_path(default_redirect_url)

          render json: {
            status: "ok",
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

        def issue_emergency_key_if_available!
          return unless current_client.has_verified_recovery_identity?

          result = ClientSecrets::IssueRecovery.call(actor: current_client, user: current_client)
          reveal = Identity::OneTimeReveal.issue!(
            actor: current_client,
            session_nonce: current_session_token&.public_id,
            value: result.raw_secret,
            purpose: Sign::App::Configuration::EmergencyKeysController::REVEAL_PURPOSE,
            metadata: { secret_public_id: result.secret.public_id },
          )
          @emergency_key_reveal_token = reveal.token
        end

        def emergency_key_reveal_token
          @emergency_key_reveal_token
        end

        def passkey_description
          params[:description].presence || I18n.t("sign.default_passkey_description")
        end

        def record_passkey_registration_step_up!
          Identity::Audit.record!(
            actor: current_client,
            event_id: ClientChronicleEvent::PASSKEY_REGISTERED,
            action: "passkey.register",
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
          )
        end

        def verification_required_action?
          step_up_bootstrap_active?
        end

        def verification_scope
          "configuration_passkey"
        end
      end
    end
  end
end
