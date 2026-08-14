# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        module Challenge
          class TotpsController < ::Auth::App::ApplicationController
            include SessionLimitGate

            include ::CloudflareTurnstile

            AUTHENTICATION_MODE = :guest

            rate_limit(
              to: 5,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "auth_app_sign_in",
              name: "mfa_totp_create_ip_burst",
              store: rate_limit_store,
              only: :create,
              with: -> { render_rate_limited(rule_name: "auth_app_sign_in_mfa_totp_create_ip_burst", retry_after: 60) },
            )
            rate_limit(
              to: 20,
              within: 15.minutes,
              by: -> { request.remote_ip },
              scope: "auth_app_sign_in",
              name: "mfa_totp_create_ip_sustained",
              store: rate_limit_store,
              only: :create,
              with: -> {
                render_rate_limited(rule_name: "auth_app_sign_in_mfa_totp_create_ip_sustained", retry_after: 900)
              },
            )
            # Per-account limit. The two rules above are keyed by source IP, so a
            # distributed attacker gets unbounded guesses against one account's
            # 6-digit TOTP. The email and SMS OTP channels already have a
            # per-account lock (OtpLockable); this is its equivalent for TOTP.
            rate_limit(
              to: 10,
              within: 15.minutes,
              by: -> {
                actor_id = pending_mfa&.dig(:user_id)
                actor_id.present? ? "client:#{actor_id}" : "unbound:#{request.remote_ip}"
              },
              scope: "auth_app_sign_in",
              name: "mfa_totp_create_account",
              store: rate_limit_store,
              only: :create,
              with: -> {
                render_rate_limited(rule_name: "auth_app_sign_in_mfa_totp_create_account", retry_after: 900)
              },
            )

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
              result = consume_totp_for(user, @totp_form.token)

              if result.accepted?
                handle_totp_success(user)
              else
                reason = result.replay? ? "totp_replay" : "totp_mismatch"
                SignRiskEmitter.emit("auth_failed", user_id: user&.id, ip: request.remote_ip, reason: reason)
                @totp_form.errors.add(:token, t("sign.app.in.mfa.verification_failed"))
                render :new, status: :unprocessable_content
              end
            end

            private

            def ensure_pending_mfa!
              return unless !pending_mfa_valid? || pending_mfa_user.nil?

              clear_pending_mfa!
              redirect_to(
                auth_app_sign_in_path,
                status: :see_other,
              )
            end

            def consume_totp_for(user, token)
              TotpWindowConsumer.call(
                credentials: user.client_totp_credentials
                  .where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
                  .order(created_at: :desc),
                token: token,
              )
            end

            def handle_totp_success(user)
              result = finalize_mfa_login!(user)
              case result[:status]
              when :session_limit_hard_reject
                render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
              when :restricted
                redirect_to(result[:redirect_path])
              when :success
                redirect_to_sign_in_sequence!(
                  pt: result[:redirect_path],
                )
              else
                redirect_to(
                  auth_app_sign_in_path,
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
end
