# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module In
      class SecretsController < GuestController
        include ::CloudflareTurnstile

        include SessionLimitGate

        AUTHENTICATION_MODE = :guest

        class SecretLoginForm
          include ActiveModel::Model

          attr_accessor :identifier, :secret_value

          validates :identifier, presence: true
          validate :identifier_matches_staff_public_id_format
          validates :secret_value, presence: true

          def self.model_name
            ActiveModel::Name.new(self, nil, "secret_login_form")
          end

          private

          def identifier_matches_staff_public_id_format
            normalized_identifier = Operator.normalize_public_id(identifier)
            return if normalized_identifier.blank?
            return if Operator::PUBLIC_ID_FORMAT.match?(normalized_identifier)

            errors.add(:identifier, :invalid)
          end
        end

        SecretVerificationResult = Struct.new(:secret, :reason, keyword_init: true)

        def new
          @secret_form = SecretLoginForm.new
        end

        def create
          @secret_form = SecretLoginForm.new(secret_params)
          unless @secret_form.valid?
            return render_failed_login(:form_invalid)
          end

          unless cloudflare_turnstile_validation["success"]
            return render_failed_login(:turnstile_failed)
          end

          staff = find_staff_by_public_id(@secret_form.identifier)
          return render_session_limit_hard_reject if session_limit_hard_reject_for?(staff)

          verification = verify_secret_for_sign_in(staff: staff, raw_secret: @secret_form.secret_value)

          if staff && verification.secret
            process_standard_login(staff)
          else
            render_failed_login(verification.reason || :identifier_not_found)
          end
        rescue StandardError => e
          Rails.logger.error(
            LogEvent.format(
              "sign.org.authentication.secret.error",
              error_class: e.class.name,
              message: e.message,
              ip: request.remote_ip,
              exception: e,
            ),
          )
          render_failed_login(:internal_error)
        end

        private

        def find_staff_by_public_id(identifier)
          normalized_identifier = Operator.normalize_public_id(identifier)
          return if normalized_identifier.blank?

          staff = Operator.find_by(public_id: normalized_identifier)
          staff if staff&.login_allowed?
        end

        def verify_secret_for_sign_in(staff:, raw_secret:)
          return SecretVerificationResult.new(reason: :identifier_not_found) unless staff

          latest_secret = staff.staff_secrets.order(created_at: :desc).first
          return SecretVerificationResult.new(reason: :secret_not_found) unless latest_secret

          secret = staff.staff_secrets.allowed_for_secret_sign_in.order(created_at: :desc).first
          return SecretVerificationResult.new(reason: :secret_not_found) unless secret
          return SecretVerificationResult.new(reason: :secret_expired) unless secret.usable_for_secret_sign_in?

          unless secret.verify_for_secret_sign_in!(raw_secret.to_s)
            return SecretVerificationResult.new(reason: :secret_mismatch)
          end

          SecretVerificationResult.new(secret: secret, reason: :success)
        end

        def process_standard_login(staff)
          pt = path_target_value
          result = establish_signed_in_session!(
            staff, pt: pt, ri: params[:ri], auth_method: "secret",
          )
          sign_in_result = sign_in_result_from_session_result(result, actor: staff)

          if sign_in_result.mfa_required?
            redirect_to(sign_in_result.redirect_to)
          elsif sign_in_result.status == :session_limit_hard_reject
            render_session_limit_hard_reject(
              message: sign_in_result.message,
              http_status: sign_in_result.response_status,
            )
          elsif sign_in_result.session_limit_pending?
            redirect_to(
              sign_in_result.redirect_to,
              notice: I18n.t("session_limit.restricted_notice"),
            )
          elsif sign_in_result.success?
            redirect_to_sign_in_sequence!(
              pt: pt,
              notice: t("sign.org.authentication.secret.create.success"),
            )
          else
            render_failed_login(sign_in_result.status)
          end
        end

        def render_failed_login(reason)
          @secret_form ||= SecretLoginForm.new
          @secret_form.errors.add(:base, invalid_secret_message)

          staff = find_staff_by_public_id(@secret_form.identifier)

          Rails.logger.info(
            LogEvent.format(
              "sign.org.authentication.secret.failed",
              reason: reason,
              identifier_present: @secret_form.identifier.present?,
              ip: request.remote_ip,
              errors: @secret_form.errors.full_messages,
            ),
          )

          Sign::Risk::Emitter.emit("auth_failed", staff_id: staff&.id) if staff

          render :new, status: :unprocessable_content, formats: :html
        end

        def invalid_secret_message
          t("sign.org.authentication.secret.create.invalid")
        end

        def secret_params
          params.fetch(:secret_login_form, {}).permit(:identifier, :secret_value)
        end
      end
    end
  end
end
