# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module In
      class SecretsController < ApplicationController
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

        before_action :reject_logged_in_session

        def new
          @secret_form = SecretLoginForm.new
        end

        def create
          @secret_form = SecretLoginForm.new(secret_params)
          @secret_form.turnstile_response = params.expect("cf-turnstile-response").to_s
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

          customer = find_user_by_identifier(@secret_form.identifier)
          return render_session_limit_hard_reject if session_limit_hard_reject_for?(customer)

          verification = verify_secret_for_sign_in(customer: customer, raw_secret: @secret_form.secret_value)

          if customer && verification.secret
            process_standard_login(customer)
          else
            failure_reason = verification.reason || :identifier_not_found
            render_failed_login(
              reason: failure_reason,
              identifier: @secret_form.identifier,
              customer: customer,
              details: verification.details,
            )
          end
        rescue StandardError => e
          Rails.event.error(
            "sign.com.authentication.secret.error",
            error_class: e.class.name,
            message: e.message,
            ip: request.remote_ip,
            exception: e,
          )
          render_failed_login(
            reason: :internal_error,
            identifier: @secret_form&.identifier,
            details: { error_class: e.class.name },
          )
        end

        private

        def identity_email_model
          CustomerEmail
        end

        def identity_telephone_model
          CustomerTelephone
        end

        def identity_from_email_record(record)
          record&.customer
        end

        def identity_from_telephone_record(record)
          record&.customer
        end

        def verify_secret_for_sign_in(customer:, raw_secret:)
          return SecretVerificationResult.new(
            reason: :identifier_not_found,
            details: {},
          ) unless customer
          return SecretVerificationResult.new(
            reason: :verified_pii_missing,
            details: {},
          ) unless customer.has_verified_pii?

          latest_secret = customer.customer_secrets.order(created_at: :desc).first
          return SecretVerificationResult.new(
            reason: :secret_not_found,
            details: {},
          ) unless latest_secret

          secret = customer.customer_secrets.allowed_for_secret_sign_in.order(created_at: :desc).first
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

        def process_standard_login(customer)
          result = complete_sign_in_or_start_mfa!(
            customer, rt: nil, ri: params[:ri], auth_method: "secret",
          )

          if result[:status] == :mfa_required
            redirect_to(result[:redirect_path], notice: t("sign.app.in.mfa.required"))
          elsif result[:status] == :session_limit_hard_reject
            render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
          elsif result[:restricted]
            redirect_to(sign_com_in_session_path, notice: I18n.t("sign.app.in.session.restricted_notice"))
          else
            if issue_bulletin!
              redirect_to(
                sign_com_in_bulletin_path(rd: params[:rd], ri: params[:ri]),
                notice: t("sign.app.authentication.secret.create.success"),
              )
            else
              safe_redirect_to_rd_or_default!(params[:rd], default_path: sign_com_configuration_path(ri: params[:ri]))
            end
          end
        end

        def secret_params
          params.fetch(:secret_login_form, {}).permit(:identifier, :secret_value)
        end

        def invalid_secret_message
          t("sign.app.authentication.secret.create.invalid")
        end

        def render_failed_login(reason:, identifier: nil, customer: nil, details: {})
          @secret_form ||= SecretLoginForm.new
          @secret_form.errors.add(:base, invalid_secret_message)

          Rails.event.info(
            "sign.com.authentication.secret.failed",
            reason: reason,
            identifier_type: detect_identifier_type(identifier.to_s),
            identifier_present: identifier.present?,
            customer_id: customer&.id,
            ip: request.remote_ip,
            errors: @secret_form.errors.full_messages,
            details: details,
          )

          Sign::Risk::Emitter.emit("auth_failed", customer_id: customer&.id) if customer

          render :new, status: :unprocessable_content, formats: :html
        end
      end
    end
  end
end
