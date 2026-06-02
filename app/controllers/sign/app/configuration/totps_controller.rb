# typed: false
# frozen_string_literal: true

require "rqrcode"

module Sign
  module App
    module Configuration
      class TotpsController < Sign::App::ApplicationController
        include ::CloudflareTurnstile

        include ::Verification::Client

        AUTHENTICATION_MODE = :private

        MAX_TOTPS = 2
        before_action :authenticate_client!
        step_up only: %i(new create), bootstrap: true
        step_up only: %i(edit update destroy)

        def index
          authorize!(ClientTotpCredential, to: :index?)
          @totps = current_client.client_totp_credentials
        end

        def new
          authorize!(ClientTotpCredential, to: :new?)
          if current_client.client_totp_credentials.count >= MAX_TOTPS
            return render plain: t("session_limit.totp_limit_reached", count: MAX_TOTPS)
          end

          @totp = ClientTotpCredential.new
          generate_totp_session
        end

        def edit
          @totp = find_totp
          authorize!(@totp)
        end

        def create
          authorize!(ClientTotpCredential, to: :create?)
          initialize_totp

          if @totp.private_key.blank?
            redirect_to(
              new_sign_app_configuration_totp_path,
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
          @totp.last_otp_at = Time.zone.at(last_otp_at)
          @totp.save!
          record_totp_registration_step_up!
          session[:private_key] = nil
          redirect_to(
            bootstrap_return_path(sign_app_configuration_totps_path),
            notice: t("messages.totp_successfully_created"),
          )
        end

        def handle_failure
          @totp.valid?
          @totp.errors.add(:first_token, t("sign.app.configuration.totps.invalid_code"))
          render_totp_qrcode(@totp.private_key)
          render :new, status: :unprocessable_content
        end

        def update
          @totp = find_totp
          authorize!(@totp)
          if @totp.update(update_params)
            redirect_to(
              sign_app_configuration_totps_path,
              notice: t("messages.totp_successfully_updated"),
            )
          else
            render :edit, status: :unprocessable_content
          end
        end

        def destroy
          @totp = find_totp
          authorize!(@totp)
          unless AuthMethodGuard.can_remove_totp?(current_client, @totp)
            redirect_to(
              sign_app_configuration_totps_path,
              alert: t(".last_method"),
            )
            return
          end

          @totp.destroy!
          redirect_to(
            sign_app_configuration_totps_path,
            notice: t("messages.totp_successfully_deleted"),
          )
        end

        private

        def find_totp
          current_client.client_totp_credentials.find_by!(public_id: params(:id))
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

        def record_totp_registration_step_up!
          Identity::Audit.record!(
            actor: current_client,
            event_id: ClientChronicleEvent::TOTP_ENABLED,
            action: "totp.enable",
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
          )
        end

        def verification_required_action?
          step_up_bootstrap_active?
        end

        def verification_scope
          "configuration_totp"
        end
      end
    end
  end
end
