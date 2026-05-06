# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class TotpsController < ApplicationController
        auth_required!

        include ::Verification::User

        MAX_TOTPS = 2
        before_action :authenticate_user!

        def index
          @totps = current_user.user_one_time_passwords
        end

        def new
          if current_user.user_one_time_passwords.count >= MAX_TOTPS
            return render plain: t("session_limit.totp_limit_reached", count: MAX_TOTPS)
          end

          @totp = UserOneTimePassword.new
          generate_totp_session
        end

        def edit
          @totp = find_totp
        end

        def create
          initialize_totp

          if @totp.private_key.blank?
            redirect_to(
              new_sign_app_configuration_totp_path,
              notice: t("sign.app.registration.email.flow.invalid"),
            )
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
          @totp = UserOneTimePassword.new(totp_params)
          @totp.private_key = session[:private_key]
          @totp.user = current_user
          @totp.user_one_time_password_status_id = UserOneTimePasswordStatus::ACTIVE
        end

        def handle_success(last_otp_at)
          @totp.last_otp_at = Time.zone.at(last_otp_at)
          @totp.save!
          session[:private_key] = nil
          redirect_to(sign_app_configuration_totps_path, notice: t("messages.totp_successfully_created"))
        end

        def handle_failure
          @totp.valid?
          @totp.errors.add(:first_token, t("sign.app.configuration.totps.invalid_code"))
          render_totp_qrcode(@totp.private_key)
          render :new, status: :unprocessable_content
        end

        def update
          @totp = find_totp
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
          @totp.destroy!
          redirect_to(
            sign_app_configuration_totps_path,
            notice: t("messages.totp_successfully_deleted"),
          )
        end

        private

        def find_totp
          current_user.user_one_time_passwords.find_by!(public_id: params[:id])
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
          ROTP::TOTP.new(private_key).verify(token)
        end

        def account_id
          current_user.user_emails.first&.address || current_user.public_id
        end

        def totp_params
          params.expect(user_one_time_password: [:first_token, :title])
        end

        def update_params
          params.expect(user_one_time_password: [:title])
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "manage_totp"
        end
      end
    end
  end
end
