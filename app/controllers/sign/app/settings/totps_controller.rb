# typed: false
# frozen_string_literal: true

require "rqrcode"

module Sign
  module App
    module Settings
      class TotpsController < ::Sign::App::ApplicationController
        include ::CloudflareTurnstile
        include ::SignAuthorityRedirect
        include ::SignTotpCeremonyDelegation
        include ::SignRequiresRecoveryPasscodes

        include ::VerificationClient

        AUTHENTICATION_MODE = :private

        MAX_TOTPS = 2
        before_action :authenticate_client!
        step_up only: %i(new create), bootstrap: true
        step_up only: []
        before_action :require_recovery_passcodes_for_mfa_registration!, only: %i(new create)
        before_action :accept_app_totp_ceremony_grant!, only: %i(new create)

        def index
          redirect_to_acme_settings_authority!
        end

        def new
          authorize!(ClientTotpCredential, to: :new?)
          if current_client.client_totp_credentials.count >= MAX_TOTPS
            return render plain: t("session_limit.totp_limit_reached", count: MAX_TOTPS)
          end

          @totp = ClientTotpCredential.new
          start_totp_ceremony!(_surface: "app", _actor: current_client, _session_ref: current_session_public_id)
          generate_totp_session
        end

        def edit
          redirect_to_acme_settings_authority!
        end

        def create
          authorize!(ClientTotpCredential, to: :create?)
          initialize_totp

          if @totp.private_key.blank?
            redirect_to(
              new_sign_app_settings_totp_path,
              notice: t("sign.app.registration.email.flow.invalid"),
            )
            return
          end

          unless cloudflare_turnstile_stealth_validation["success"]
            @totp.errors.add(:base, t("turnstile_error"))
            render_totp_qrcode(@totp.private_key)
            render :new, status: :unprocessable_content
            return
          end

          last_otp_at = verify_totp(@totp.private_key, @totp.first_token)

          if last_otp_at
            handle_success(last_otp_at)
          else
            handle_failure
          end
        end

        def initialize_totp
          @totp = ClientTotpCredential.new(totp_params)
          @totp.private_key = session[:private_key]
          @totp.user = current_client
          @totp.user_totp_credential_status_id = ClientTotpCredentialStatus::ACTIVE
        end

        def handle_success(last_otp_at)
          last_otp_at_time = Time.zone.at(last_otp_at)
          finish_totp_ceremony!(
            surface: "app",
            actor: current_client,
            session_ref: current_session_public_id,
            private_key: @totp.private_key,
            title: @totp.title,
            last_otp_at: last_otp_at_time,
          )
          session[:private_key] = nil
          reset_totp_ceremony_session!
          redirect_to(
            bootstrap_return_path(
              sign_app_settings_totps_url(
                ri: params[:ri],
                host: ENV.fetch(
                  "ID_SERVICE_URL", "id.app.localhost",
                ),
              ),
            ),
            notice: t("messages.totp_successfully_created"),
            allow_other_host: cross_host_redirect_allowed?,
          )
        end

        def handle_failure
          @totp.valid?
          @totp.errors.add(:first_token, t("sign.app.settings.totps.invalid_code"))
          render_totp_qrcode(@totp.private_key)
          render :new, status: :unprocessable_content
        end

        def update
          redirect_to_acme_settings_authority!
        end

        def destroy
          redirect_to_acme_settings_authority!
        end

        private

        def find_totp
          current_client.client_totp_credentials.find_by!(public_id: params(:id))
        end

        def accept_app_totp_ceremony_grant!
          return true if accept_totp_ceremony_grant!(surface: "app")

          redirect_to(
            sign_app_settings_totps_path(ri: params[:ri]),
            alert: I18n.t("errors.messages.invalid"),
            status: :see_other,
          )
          false
        end

        def redirect_to_acme_settings_authority!
          redirect_to_acme_authority!(acme_settings_authority_path, query: request.query_parameters)
        end

        def generate_totp_session
          session[:private_key] ||= ROTP::Base32.random_base32
          @png = generate_qrcode(session[:private_key])
        end

        def render_totp_qrcode(private_key)
          @png = generate_qrcode(private_key)
        end

        def generate_qrcode(private_key)
          totp = ROTP::TOTP.new(private_key)
          RQRCode::QRCode.new(totp.provisioning_uri(account_id)).as_png
        end

        def verify_totp(private_key, token)
          ROTP::TOTP.new(private_key).verify(normalized_totp_token(token))
        end

        def normalized_totp_token(token)
          token.to_s.gsub(/\D/, "")
        end

        def account_id
          current_client.client_emails.first&.address || current_client.public_id
        end

        def totp_params
          params(user_totp_credential: [:first_token, :title])
        end

        def update_params
          params(user_totp_credential: [:title])
        end

        def verification_required_action?
          step_up_bootstrap_active? && %w(new create).include?(action_name)
        end

        def verification_scope
          "settings_totp"
        end

        def recovery_passcode_requirement_actor
          current_client
        end

        def recovery_passcode_requirement_credential_class
          ClientSecretCredential
        end

        def recovery_passcode_setup_url
          sign_app_settings_secret_credentials_url(
            ri: params[:ri],
            host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
          )
        end
      end
    end
  end
end
