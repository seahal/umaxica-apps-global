# typed: false
# frozen_string_literal: true

module Sign
  module App
    module In
      module Challenge
        class TotpsController < Sign::App::In::GuestController
          include SessionLimitGate
          include ::CloudflareTurnstile

          class TotpChallengeForm
            include ActiveModel::Model

            attr_accessor :token

            validates :token, presence: true, length: { is: 6 }

            def self.model_name
              ActiveModel::Name.new(self, nil, "totp_challenge_form")
            end
          end

          before_action :ensure_pending_mfa!

          def new
            @totp_form = TotpChallengeForm.new
          end

          def create
            @totp_form = TotpChallengeForm.new(totp_params)
            unless @totp_form.valid?
              return render :new, status: :unprocessable_content
            end

            unless cloudflare_turnstile_stealth_validation["success"]
              @totp_form.errors.add(
                :base, t("session_limit.turnstile_failed"),
              )
              return render :new, status: :unprocessable_content
            end

            user = pending_mfa_user
            last_otp_at, totp_record = verify_totp_for(user, @totp_form.token)

            if last_otp_at
              handle_totp_success(user, totp_record, last_otp_at)
            else
              Sign::Risk::Emitter.emit("auth_failed", user_id: user&.id, ip: request.remote_ip, reason: "totp_mismatch")
              @totp_form.errors.add(:token, t("sign.app.in.mfa.verification_failed"))
              render :new, status: :unprocessable_content
            end
          end

          private

          def ensure_pending_mfa!
            return unless !pending_mfa_valid? || pending_mfa_user.nil?

            clear_pending_mfa!
            redirect_to(
              new_sign_app_in_path,
              alert: I18n.t("sign.app.in.mfa.session_expired"),
              status: :see_other,
            )
          end

          def verify_totp_for(user, token)
            user.client_one_time_passwords
              .where(user_identity_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE)
              .order(created_at: :desc)
              .each do |totp|
              last_otp_at = ROTP::TOTP.new(totp.private_key).verify(token.to_s)
              return [last_otp_at, totp] if last_otp_at
            end
            [nil, nil]
          end

          def handle_totp_success(user, totp_record, last_otp_at)
            totp_record&.update!(last_otp_at: Time.zone.at(last_otp_at))

            result = finalize_mfa_login!(user)
            case result[:status]
            when :session_limit_hard_reject
              render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
            when :restricted
              redirect_to(result[:redirect_path], notice: I18n.t("sign.app.in.session.restricted_notice"))
            when :success
              redirect_to_sign_in_sequence!(
                rt: result[:redirect_path],
                notice: I18n.t("sign.app.in.mfa.totp.success"),
              )
            else
              redirect_to(
                new_sign_app_in_path,
                alert: I18n.t("sign.app.in.mfa.verification_failed"),
                status: :see_other,
              )
            end
          end

          def totp_params
            params.fetch(:totp_challenge_form, {}).permit(:token)
          end
        end
      end
    end
  end
end
