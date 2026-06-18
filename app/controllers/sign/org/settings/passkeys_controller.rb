# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      # PasskeysController handles Passkey registration and management for operators.
      #
      # Registration Flow:
      # 1. Operator visits /settings/passkeys/new
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
      class PasskeysController < ::Sign::Org::ApplicationController
        include ::VerificationOperator

        include SignWebauthn
        include SignPasskeyCeremonyDelegation
        include ::SignRequiresRecoveryPasscodes

        include ::CloudflareTurnstile
        include ::SignAuthorityRedirect

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        # Object-level authorization (ActionPolicy): index/create gate the actor type; show/edit/
        # update/destroy authorize the owned record (set_passkey is owner-scoped -> 404 first).
        # Step-up / Turnstile / WebAuthn-challenge guards remain in place for the registration ceremony.
        before_action :authorize_passkeys!, only: %i(index)
        before_action :authorize_passkey_create!, only: %i(create)
        step_up only: %i(new create options verification), bootstrap: true
        before_action :require_recovery_passcodes_for_mfa_registration!, only: %i(new create options verification)
        before_action :accept_org_passkey_ceremony_grant!, only: %i(new options verification)
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
          @passkey = current_operator.staff_passkeys.new
          start_passkey_ceremony!(_surface: "org", _actor: current_operator, _session_ref: current_session_public_id)
        end

        # GET /settings/passkeys/:id/edit
        def edit
          redirect_to_acme_settings_authority!
        end

        # POST /settings/passkeys
        # WebAuthn registration is driven by new/options/verification; REST create
        # hands clients to that ceremony without mutating local Sign state.
        def create
          respond_to do |format|
            format.html do
              redirect_to(
                new_sign_org_settings_passkey_path(ri: params[:ri]),
                status: :see_other,
              )
            end
            format.json do
              render json: {
                status: "registration_ceremony_required",
                redirect_path: new_sign_org_settings_passkey_path(ri: params[:ri]),
              }, status: :accepted
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
            current_operator.staff_passkeys.map do |passkey|
              { id: passkey.webauthn_id }
            end

          challenge_id, creation_options = create_registration_challenge(
            resource: current_operator,
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

          if challenge_id.blank?
            return render json: {
              error: I18n.t("errors.webauthn.challenge_id_required"),
            }, status: :bad_request
          end

          with_challenge(challenge_id, purpose: :registration) do |challenge|
            # Parse credential from request
            credential = WebAuthn::Credential.from_create(
              credential_params.to_h,
              relying_party: webauthn_relying_party,
            )

            # Verify the credential
            credential.verify(challenge)

            passkey = commit_passkey_ceremony!(credential, challenge_id)

            render json: {
              status: "ok",
              passkey_id: passkey.id,
              redirect_url: bootstrap_return_path(
                sign_org_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("ID_STAFF_URL", "id.org.localhost")),
              ),
            }, status: :created
          end
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

        # PATCH/PUT /settings/passkeys/:id
        def update
          redirect_to_acme_settings_authority!
        end

        # DELETE /settings/passkeys/:id
        def destroy
          redirect_to_acme_settings_authority!
        end

        private

        def authorize_passkeys!
          authorize!(OperatorPasskey, to: :index?)
        end

        def authorize_passkey_create!
          authorize!(OperatorPasskey, to: :create?)
        end

        def verify_settings_passkey_turnstile!
          return true if cloudflare_turnstile_stealth_validation["success"]

          respond_to do |format|
            format.html do
              redirect_back_or_to(
                sign_org_settings_passkeys_path(ri: params[:ri]), alert: t("turnstile_error"),
                                                                  status: :see_other,
              )
            end
            format.json { render json: { error: t("turnstile_error") }, status: :unprocessable_content }
          end
          false
        end

        def accept_org_passkey_ceremony_grant!
          return true if accept_passkey_ceremony_grant!(surface: "org")

          respond_to do |format|
            format.html do
              redirect_to(
                sign_org_settings_passkeys_path(ri: params[:ri]),
                alert: I18n.t("errors.messages.invalid"),
                status: :see_other,
              )
            end
            format.json { render json: { error: I18n.t("errors.messages.invalid") }, status: :bad_request }
          end
          false
        end

        def set_passkey
          @passkey = current_operator.staff_passkeys.find(params(:id))
        end

        def credential_params
          params(
            credential: [
              :id,
              :rawId,
              :type,
              :authenticatorAttachment,
              { transports: [] },
              { response: %i(clientDataJSON attestationObject) },
              { clientExtensionResults: {} },
            ],
          )
        end

        def update_params
          key = %i(operator_passkey staff_passkey passkey).find { |candidate| params.key?(candidate) }
          return {} unless key

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
            surface: "org",
            actor: current_operator,
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

        def recovery_passcode_requirement_actor
          current_operator
        end

        def recovery_passcode_requirement_credential_class
          OperatorSecretCredential
        end

        def recovery_passcode_setup_url
          sign_org_settings_secret_credentials_url(
            ri: params[:ri],
            host: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
          )
        end

        # Compatibility entry only. acme/www owns account-facing passkey lifecycle.
        def redirect_to_acme_settings_authority!
          redirect_to_sign_authority!(request.path, query: request.query_parameters)
        end
      end
    end
  end
end
