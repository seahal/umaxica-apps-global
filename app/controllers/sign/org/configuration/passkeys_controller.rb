# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      # PasskeysController handles Passkey registration and management for operators.
      #
      # Registration Flow:
      # 1. Operator visits /configuration/passkeys/new
      # 2. POST /configuration/passkeys/options to get WebAuthn challenge
      # 3. Browser performs navigator.credentials.create()
      # 4. POST /configuration/passkeys/verification with credential + challenge_id
      # 5. Server verifies and creates OperatorPasskey record
      #
      # CRUD operations:
      # - GET /configuration/passkeys (index)
      # - GET /configuration/passkeys/:id (show)
      # - GET /configuration/passkeys/:id/edit (edit)
      # - PATCH /configuration/passkeys/:id (update - description only)
      # - DELETE /configuration/passkeys/:id (destroy)
      class PasskeysController < PrivateController
        include ::Verification::Operator
        include Sign::Webauthn

        before_action :authenticate_operator!
        before_action only: %i(new create options verification) do
          require_step_up_unless_bootstrap!(scope: verification_scope)
        end
        before_action :set_passkey, only: %i(show edit update destroy)
        # GET /configuration/passkeys
        def index
          @passkeys = current_operator.staff_passkeys.order(created_at: :desc)
        end

        # GET /configuration/passkeys/:id
        def show
        end

        # GET /configuration/passkeys/new
        def new
          @passkey = current_operator.staff_passkeys.new
        end

        # GET /configuration/passkeys/:id/edit
        def edit
        end

        # POST /configuration/passkeys
        # Reserved for future non-WebAuthn registration flow.
        def create
          respond_to do |format|
            format.html do
              redirect_to(
                new_sign_org_configuration_passkey_path,
                alert: t("messages.not_implemented"),
              )
            end
            format.json do
              render json: { error: t("messages.not_implemented") }, status: :unprocessable_content
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
        rescue Sign::Webauthn::OriginValidationError => e
          Rails.event.error("webauthn.origin_validation_failed", message: e.message)
          render json: { error: I18n.t("errors.webauthn.origin_invalid") }, status: :forbidden
        rescue Sign::Webauthn::ChallengeError, WebAuthn::Error, ArgumentError => e
          Rails.event.error("webauthn.registration_options_failed", error_class: e.class.name, message: e.message)
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

            # Create the passkey record
            passkey = current_operator.staff_passkeys.new(
              webauthn_id: credential.id,
              public_key: credential.public_key,
              sign_count: credential.sign_count,
              description: passkey_description,
            )

            passkey.save!

            render json: {
              status: "ok",
              passkey_id: passkey.id,
              redirect_url: bootstrap_return_path(sign_org_configuration_passkeys_path),
            }, status: :created
          end
        rescue Sign::Webauthn::ChallengeNotFoundError,
               Sign::Webauthn::ChallengeExpiredError => e
          Rails.logger.warn("WebAuthn challenge error: #{e.message}")
          render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
        rescue Sign::Webauthn::ChallengePurposeMismatchError => e
          Rails.logger.warn("WebAuthn challenge purpose mismatch: #{e.message}")
          render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
        rescue WebAuthn::Error => e
          Rails.logger.warn("WebAuthn registration failed: #{e.message}")
          render json: { error: I18n.t("errors.webauthn.verification_failed") },
                 status: :unprocessable_content
        rescue ActiveRecord::RecordNotUnique
          render json: { error: I18n.t("errors.webauthn.credential_already_registered") }, status: :conflict
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn("WebAuthn passkey creation failed: #{e.message}")
          render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
        end

        # PATCH/PUT /configuration/passkeys/:id
        def update
          if @passkey.update(update_params)
            respond_to do |format|
              format.html do
                redirect_to(
                  sign_org_configuration_passkey_path(@passkey),
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
          unless AuthMethodGuard.can_remove_passkey?(current_operator, @passkey)
            respond_to do |format|
              format.html do
                redirect_to(
                  sign_org_configuration_passkeys_path,
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
                sign_org_configuration_passkeys_path,
                status: :see_other,
                notice: t("messages.passkey_successfully_destroyed"),
              )
            end
            format.json { head :no_content }
          end
        end

        private

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

        def passkey_description
          params[:description].presence || I18n.t("sign.default_passkey_description")
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
