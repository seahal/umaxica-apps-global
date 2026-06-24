# typed: false
# frozen_string_literal: true

require "rqrcode"

module Sign
  module App
    module Settings
      class TotpsController < ::Sign::App::ApplicationController
        include ::CloudflareTurnstile
        include ::SignAuthorityRedirect
        include ::SignSettingsTotpRegistration
        include ::SignRequiresRecoveryPasscodes

        include ::VerificationClient

        AUTHENTICATION_MODE = :private

        MAX_TOTPS = 2
        before_action :authenticate_client!
        step_up only: %i(new create), bootstrap: true
        step_up only: []
        before_action :require_recovery_passcodes_for_mfa_registration!, only: %i(new create)

        def index
          @totps = current_client.client_totp_credentials.order(created_at: :asc)
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
          find_totp
          authorize!(@totp)
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

          recovery_passcode_top_up = top_up_recovery_passcodes_after_totp_registration
          redirect_url =
            if recovery_passcode_top_up.raw_values.any?
              recovery_passcode_reveal_url(recovery_passcode_top_up.raw_values)
            else
              sign_app_settings_totps_url(
                ri: params[:ri],
                host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
              )
            end
          redirect_to(
            bootstrap_return_path(redirect_url),
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
          find_totp
          authorize!(@totp)

          if @totp.update(update_params)
            redirect_to(sign_app_settings_totp_path(@totp.public_id, ri: params[:ri]), status: :see_other)
          else
            render :edit, status: :unprocessable_content
          end
        end

        # DELETE /settings/totps/:id
        def destroy
          totp = current_client.client_totp_credentials.find_by!(public_id: params.expect(:id))
          authorize!(totp)
          unless AuthMethodGuard.can_remove_totp?(current_client, totp)
            redirect_to(
              sign_app_settings_totps_path(ri: params[:ri]),
              alert: t(".last_method"),
              status: :see_other,
            )
            return
          end
          totp.destroy!
          redirect_to(sign_app_settings_totps_path(ri: params[:ri]), status: :see_other)
        end

        private

        def find_totp
          @totp = current_client.client_totp_credentials.find_by!(public_id: params.expect(:id))
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

        def recovery_passcode_requirement_active_strong_credential_count
          current_client.client_passkeys.active.count +
            current_client.client_totp_credentials.where(
              user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
            ).count
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

        def top_up_recovery_passcodes_after_totp_registration
          RecoveryPasscodeTopUp.call(
            actor: current_client,
            credential_class: ClientSecretCredential,
            target_count: RecoveryPasscodeTopUp::TARGET_ACTIVE_RECOVERY_PASSCODES,
          )
        end

        def recovery_passcode_reveal_url(raw_values)
          return if raw_values.blank?

          reveal = IdentityOneTimeReveal.issue!(
            actor: current_client,
            session_nonce: current_client.public_id,
            value: raw_values,
            purpose: "app.recovery_passcodes",
            metadata: {},
          )
          sign_app_settings_secrets_url(
            ri: params[:ri],
            token: reveal.token,
            host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
          )
        end
      end
    end
  end
end
