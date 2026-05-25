# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module In
      class SecretsController < GuestController
        AUTHENTICATION_MODE = :guest

        include ::CloudflareTurnstile
        include EmailValidation
        include IdentifierDetection
        include Common::Redirect
        include SessionLimitGate

        class SecretLoginForm
          include ActiveModel::Model

          attr_accessor :identifier, :secret_value, :turnstile_response

          validates :secret_value, presence: true
          validate :identifier_present_and_valid

          def self.model_name
            ActiveModel::Name.new(self, nil, "secret_login_form")
          end

          private

          def identifier_present_and_valid
            value = identifier.to_s.strip
            return errors.add(:base, :blank) if value.blank?
            return if value.include?("@") || value.include?("+")

            errors.add(:identifier, :invalid)
          end
        end

        SecretVerificationResult = Struct.new(:secret, :reason, :details, keyword_init: true)

        def new
          @secret_form = SecretLoginForm.new
        end

        def create
          @secret_form = SecretLoginForm.new(secret_params)
          @secret_form.turnstile_response = params("cf-turnstile-response").to_s
          unless @secret_form.valid?
            return render_failed_login(
              reason: :form_invalid,
              identifier: @secret_form.identifier,
              details: { errors: @secret_form.errors.full_messages },
            )
          end
          unless cloudflare_turnstile_validation["success"]
            return render_failed_login(reason: :turnstile_failed, identifier: @secret_form.identifier)
          end

          visitor = find_user_by_identifier(@secret_form.identifier)
          return render_session_limit_hard_reject if session_limit_hard_reject_for?(visitor)

          verification = verify_secret_for_sign_in(visitor: visitor, raw_secret: @secret_form.secret_value)

          if visitor && verification.secret
            process_standard_login(visitor)
          else
            failure_reason = verification.reason || :identifier_not_found
            render_failed_login(
              reason: failure_reason,
              identifier: @secret_form.identifier,
              visitor: visitor,
              details: verification.details,
            )
          end
        rescue StandardError => e
          Rails.logger.error(
            LogEvent.format(
              "sign.com.authentication.secret.error",
              error_class: e.class.name,
              message: e.message,
              ip: request.remote_ip,
              exception: e,
            ),
          )
          render_failed_login(
            reason: :internal_error,
            identifier: @secret_form&.identifier,
            details: { error_class: e.class.name },
          )
        end

        private

        def identity_email_model
          VisitorEmail
        end

        def identity_telephone_model
          VisitorTelephone
        end

        def identity_from_email_record(record)
          record&.visitor
        end

        def identity_from_telephone_record(record)
          record&.visitor
        end

        def verify_secret_for_sign_in(visitor:, raw_secret:)
          return SecretVerificationResult.new(
            reason: :identifier_not_found,
            details: {},
          ) unless visitor
          return SecretVerificationResult.new(
            reason: :verified_pii_missing,
            details: {},
          ) unless visitor.has_verified_pii?

          latest_secret = visitor.visitor_secrets.order(created_at: :desc).first
          return SecretVerificationResult.new(
            reason: :secret_not_found,
            details: {},
          ) unless latest_secret

          secret = visitor.visitor_secrets.allowed_for_secret_sign_in.order(created_at: :desc).first
          return SecretVerificationResult.new(reason: :secret_expired, details: {}) unless secret
          return SecretVerificationResult.new(
            reason: :secret_expired,
            details: {},
          ) unless secret.usable_for_secret_sign_in?

          unless secret.verify_for_secret_sign_in!(raw_secret.to_s)
            return SecretVerificationResult.new(
              reason: :secret_mismatch,
              details: { secret_id: secret.id },
            )
          end

          SecretVerificationResult.new(
            secret: secret, reason: :success,
            details: { secret_id: secret.id },
          )
        end

        def process_standard_login(visitor)
          result = establish_signed_in_session!(
            visitor, rt: nil, ri: params[:ri], auth_method: "secret",
          )
          sign_in_result = sign_in_result_from_session_result(result, actor: visitor)

          if sign_in_result.mfa_required?
            redirect_to(sign_in_result.redirect_to, notice: t("sign.app.in.mfa.required"))
          elsif sign_in_result.status == :session_limit_hard_reject
            render_session_limit_hard_reject(
              message: sign_in_result.message,
              http_status: sign_in_result.response_status,
            )
          elsif sign_in_result.session_limit_pending?
            redirect_to(sign_in_result.redirect_to, notice: I18n.t("sign.app.in.session.restricted_notice"))
          else
            redirect_to_sign_in_sequence!(
              rt: redirect_parameter_value,
              notice: t("sign.app.authentication.secret.create.success"),
            )
          end
        end

        def secret_params
          params.fetch(:secret_login_form, {}).permit(:identifier, :secret_value)
        end

        def invalid_secret_message
          t("sign.app.authentication.secret.create.invalid")
        end

        def render_failed_login(reason:, identifier: nil, visitor: nil, details: {})
          @secret_form ||= SecretLoginForm.new
          @secret_form.errors.add(:base, invalid_secret_message)

          Rails.logger.info(
            LogEvent.format(
              "sign.com.authentication.secret.failed",
              reason: reason,
              identifier_type: detect_identifier_type(identifier.to_s),
              identifier_present: identifier.present?,
              visitor_id: visitor&.id,
              ip: request.remote_ip,
              errors: @secret_form.errors.full_messages,
              details: details,
            ),
          )

          Sign::Risk::Emitter.emit("auth_failed", visitor_id: visitor&.id) if visitor

          render :new, status: :unprocessable_content, formats: :html
        end
      end
    end
  end
end
