# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      # Passkey registration and management for users.
      #
      # Registration Flow:
      # 1. User visits /settings/passkeys/new
      # 2. POST /settings/passkeys/options to get WebAuthn challenge
      # 3. Browser performs navigator.credentials.create()
      # 4. POST /settings/passkeys/verification with credential + challenge_id
      # 5. sign/id verifies the ceremony and commits the passkey binding
      class PasskeysController < ::Auth::App::ApplicationController
        include ::VerificationClient
        include SignSettingsPasskeyRegistration
        include ::PasskeyRegistrationFlow
        include ::SignRequiresRecoveryPasscodes
        include ::SignAuthorityRedirect

        include ::CloudflareTurnstile

        AUTHENTICATION_MODE = :private

        before_action :authenticate_client!
        step_up only: %i(new create options verification), bootstrap: true
        step_up only: :destroy
        before_action :require_recovery_passcodes_for_mfa_registration!, only: %i(new create options verification)
        before_action :verify_settings_passkey_turnstile!, only: :options

        # GET /settings/passkeys
        def index
          authorize!(ClientPasskey, to: :index?)
          @passkeys = current_client.client_passkeys.order(created_at: :asc)
        end

        # GET /settings/passkeys/:id
        def show
          set_passkey
          authorize!(@passkey)
        end

        # GET /settings/passkeys/new
        def new
          authorize!(ClientPasskey, to: :new?)
          @passkey = current_client.client_passkeys.new
          start_passkey_ceremony!(_surface: "app", _actor: current_client, _session_ref: current_session_public_id)
        end

        # GET /settings/passkeys/:id/edit
        def edit
          set_passkey
          authorize!(@passkey)
        end

        # POST /settings/passkeys
        # WebAuthn registration is driven by new/options/verification; REST create
        # hands clients to that ceremony without mutating local Sign state.
        def create
          @passkey = current_client.client_passkeys.new(description: passkey_description)
          authorize!(@passkey)

          respond_to do |format|
            format.html do
              redirect_to(
                new_auth_app_settings_passkey_path(ri: params[:ri]),
                status: :see_other,
              )
            end
            format.json do
              render json: { error: passkey_verification_required_message },
                     status: :unprocessable_content
            end
          end
        end

        # POST /settings/passkeys/options
        def options = (authorize!(ClientPasskey, to: :create?); render_passkey_registration_options)

        # POST /settings/passkeys/verification
        def verification = (authorize!(ClientPasskey, to: :create?); verify_passkey_registration)

        # PATCH/PUT /settings/passkeys/:id
        def update
          set_passkey
          authorize!(@passkey)

          if @passkey.update(update_params)
            redirect_to(auth_app_settings_passkey_path(@passkey.public_id, ri: params[:ri]), status: :see_other)
          else
            render :edit, status: :unprocessable_content
          end
        end

        # DELETE /settings/passkeys/:id
        def destroy
          passkey = current_client.client_passkeys.find_by!(public_id: params.expect(:id))
          authorize!(passkey)

          unless AuthMethodGuard.can_remove_passkey?(current_client, passkey)
            redirect_last_method
            return
          end

          passkey.destroy!
          redirect_to(
            auth_app_settings_passkeys_path(ri: params[:ri]),
            status: :see_other,
          )
        end

        private

        def set_passkey
          @passkey = current_client.client_passkeys.find_by!(public_id: params.expect(:id))
        end

        def update_params
          key = %i(client_passkey user_passkey passkey).find { |candidate| params.key?(candidate) }
          return {} unless key

          params.fetch(key, {}).permit(:description)
        end

        def redirect_last_method
          redirect_to(
            auth_app_settings_passkeys_path(ri: params[:ri]),
            status: :see_other,
          )
        end

        def verify_settings_passkey_turnstile!
          return true if cloudflare_turnstile_stealth_validation["success"]

          respond_to do |format|
            format.html do
              redirect_back_or_to(
                auth_app_settings_passkeys_path(ri: params[:ri]),
                status: :see_other,
              )
            end
            format.json { render json: { error: t("turnstile_error") }, status: :unprocessable_content }
          end
          false
        end

        def passkey_verification_required_message
          I18n.t("errors.webauthn.verification_required")
        end

        def passkey_registration_actor = current_client

        def passkey_registration_passkeys = current_client.client_passkeys

        def passkey_registration_redirect_url
          auth_app_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
        end

        def passkey_registration_log_prefix = "sign.webauthn.registration"

        def recovery_passcode_requirement_active_strong_credential_count
          current_client.client_passkeys.active.count +
            current_client.client_totp_credentials.where(
              user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
            ).count
        end

        def recovery_passcode_requirement_actor = current_client

        def recovery_passcode_requirement_credential_class = ClientSecretCredential

        def recovery_passcode_setup_url
          base_app_identity_secrets_url(
            ri: params[:ri],
            host: base_authority_host,
          )
        end

        def recovery_passcode_top_up_actor = current_client

        def recovery_passcode_top_up_credential_class = ClientSecretCredential

        def recovery_passcode_reveal_redirect_url(token)
          base_app_identity_secrets_url(
            ri: params[:ri],
            token: token,
            host: base_authority_host,
          )
        end
      end
    end
  end
end
