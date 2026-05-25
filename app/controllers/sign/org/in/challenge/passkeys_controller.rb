# typed: false
# frozen_string_literal: true

require "base64"

module Sign
  module Org
    module In
      module Challenge
        class PasskeysController < Sign::Org::In::GuestController
          AUTHENTICATION_MODE = :guest

          include Sign::Webauthn
          include SessionLimitGate
          include ::CloudflareTurnstile

          before_action :ensure_pending_mfa!

          def new
            @mfa_staff = pending_mfa_user
            passkeys = active_passkeys_for(@mfa_staff)

            if passkeys.empty?
              redirect_to(
                sign_org_in_challenge_path,
                alert: I18n.t("errors.webauthn.no_passkeys_available"),
                status: :see_other,
              )
              return
            end

            @passkey_challenge_id, @passkey_request_options =
              create_authentication_challenge(
                allow_credentials: passkeys.map { |pk|
                  { id: pk.webauthn_id }
                }, user_verification: "discouraged",
              )
          rescue Sign::Webauthn::OriginValidationError => e
            Rails.logger.error(LogEvent.format("webauthn.origin_validation_failed", message: e.message))
            redirect_to(
              sign_org_in_challenge_path, alert: I18n.t("errors.webauthn.origin_invalid"),
                                          status: :see_other,
            )
          end

          def create
            unless cloudflare_turnstile_stealth_validation["success"]
              redirect_to(
                new_sign_org_in_challenge_passkey_path,
                alert: I18n.t("session_limit.turnstile_failed"),
                status: :see_other,
              )
              return
            end

            with_challenge(passkey_params[:challenge_id], purpose: :authentication) do |challenge|
              verify_passkey!(challenge)
            end
          rescue Sign::Webauthn::ChallengeNotFoundError, Sign::Webauthn::ChallengeExpiredError,
                 Sign::Webauthn::ChallengePurposeMismatchError
            redirect_to(
              sign_org_in_challenge_path, alert: I18n.t("errors.webauthn.challenge_invalid"),
                                          status: :see_other,
            )
          rescue WebAuthn::SignCountVerificationError
            redirect_to(
              sign_org_in_challenge_path, alert: I18n.t("errors.webauthn.sign_count_mismatch"),
                                          status: :see_other,
            )
          rescue WebAuthn::Error
            redirect_to(
              sign_org_in_challenge_path, alert: I18n.t("errors.webauthn.verification_failed"),
                                          status: :see_other,
            )
          end

          private

          def ensure_pending_mfa!
            return unless !pending_mfa_valid? || pending_mfa_user.nil?

            clear_pending_mfa!
            redirect_to(
              new_sign_org_in_path,
              alert: I18n.t("sign.org.in.mfa.session_expired"),
              status: :see_other,
            )
          end

          def active_passkeys_for(staff)
            staff.staff_passkeys.where(status_id: OperatorPasskeyStatus::ACTIVE)
          end

          def passkey_params
            params.fetch(:mfa_passkey_form, {}).permit(:challenge_id, :credential_json)
          end

          def verify_passkey!(challenge)
            credential_payload = JSON.parse(passkey_params[:credential_json].to_s)
            credential = WebAuthn::Credential.from_get(
              credential_payload,
              relying_party: webauthn_relying_party,
            )
            passkey = OperatorPasskey.find_by(webauthn_id: credential.id)

            staff = pending_mfa_user
            unless passkey && staff && passkey.staff_id == staff.id
              Sign::Risk::Emitter.emit(
                "auth_failed", staff_id: staff&.id, ip: request.remote_ip,
                               reason: "mfa_passkey_mismatch",
              )
              redirect_to(
                sign_org_in_challenge_path,
                alert: I18n.t("errors.webauthn.credential_not_found"),
                status: :see_other,
              )
              return
            end

            credential.verify(challenge, public_key: passkey.public_key, sign_count: passkey.sign_count)
            passkey.update!(sign_count: credential.sign_count, last_used_at: Time.current)

            complete_mfa_login!(staff)
          rescue JSON::ParserError
            redirect_to(
              sign_org_in_challenge_path, alert: I18n.t("errors.webauthn.verification_failed"),
                                          status: :see_other,
            )
          end

          def complete_mfa_login!(staff)
            result = finalize_mfa_login!(staff)
            case result[:status]
            when :session_limit_hard_reject
              render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
            when :restricted
              redirect_to(
                result[:redirect_path], notice: I18n.t(
                  "sign.org.in.session.restricted_notice",
                ),
              )
            when :success
              redirect_to_sign_in_sequence!(
                rt: result[:redirect_path],
                notice: I18n.t("sign.org.in.mfa.passkey.success"),
              )
            else
              redirect_to(
                new_sign_org_in_path,
                alert: I18n.t("sign.org.in.mfa.verification_failed"),
                status: :see_other,
              )
            end
          end
        end
      end
    end
  end
end
