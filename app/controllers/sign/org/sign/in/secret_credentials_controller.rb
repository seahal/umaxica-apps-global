# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Sign
      module In
        class SecretCredentialsController < ::Sign::Org::ApplicationController
          include ::CloudflareTurnstile

          include MinimumResponseBudget

          include SessionLimitGate

          AUTHENTICATION_MODE = :guest

          SecretVerificationResult = Struct.new(:secret_credential, :reason, :details, keyword_init: true)

          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "sign_org_sign_in",
            name: "secret_credential_create_ip_burst",
            store: rate_limit_store,
            only: :create,
            with: -> {
              render_rate_limited(rule_name: "sign_org_sign_in_secret_credential_create_ip_burst", retry_after: 60)
            },
          )
          rate_limit(
            to: 20,
            within: 15.minutes,
            by: -> { request.remote_ip },
            scope: "sign_org_sign_in",
            name: "secret_credential_create_ip_sustained",
            store: rate_limit_store,
            only: :create,
            with: -> {
              render_rate_limited(rule_name: "sign_org_sign_in_secret_credential_create_ip_sustained", retry_after: 900)
            },
          )
          before_action :start_minimum_response_budget
          after_action :enforce_minimum_response_budget

          class SecretLoginForm
            include ActiveModel::Model

            attr_accessor :identifier, :secret_credential_value

            validates :identifier, presence: true
            validate :identifier_matches_staff_public_id_format
            validates :secret_credential_value, presence: true

            def self.model_name
              ActiveModel::Name.new(self, nil, "secret_credential_login_form")
            end

            private

            def identifier_matches_staff_public_id_format
              normalized_identifier = Operator.normalize_public_id(identifier)
              return if normalized_identifier.blank?
              return if Operator::PUBLIC_ID_FORMAT.match?(normalized_identifier)

              errors.add(:identifier, :invalid)
            end
          end

          def new
            @secret_credential_form = SecretLoginForm.new
          end

          def create
            @secret_credential_form = SecretLoginForm.new(secret_credential_params)
            unless @secret_credential_form.valid?
              return render_failed_login(:form_invalid)
            end

            unless cloudflare_turnstile_validation["success"]
              return render_failed_login(:turnstile_failed)
            end

            staff = find_staff_by_public_id(@secret_credential_form.identifier)
            return render_session_limit_hard_reject if session_limit_hard_reject_for?(staff)

            verification = verify_secret_credential_for_sign_in(
              staff: staff,
              raw_secret_credential: @secret_credential_form.secret_credential_value,
            )

            if staff && verification.secret_credential
              process_standard_login(staff)
            else
              render_failed_login(verification.reason || :identifier_not_found)
            end
          rescue StandardError => e
            Rails.logger.error(
              JitLogEvent.format(
                "sign.org.authentication.secret_credential.error",
                error_class: e.class.name,
                message: e.message,
                ip: request.remote_ip,
                ri: current_region_identifier,
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

          def verify_secret_credential_for_sign_in(staff:, raw_secret_credential:)
            return SecretVerificationResult.new(reason: :identifier_not_found) unless staff

            latest_secret_credential = staff.staff_secret_credentials.order(created_at: :desc).first
            return SecretVerificationResult.new(reason: :secret_credential_not_found) unless latest_secret_credential

            secret_credential = staff.staff_secret_credentials
              .allowed_for_secret_credential_sign_in
              .order(created_at: :desc)
              .first
            return SecretVerificationResult.new(reason: :secret_credential_not_found) unless secret_credential
            return SecretVerificationResult.new(reason: :secret_credential_expired) unless
              secret_credential.usable_for_secret_credential_sign_in?

            verification =
              if secret_credential.new_axis_secret_credential?
                ::SignSecretVerify.call(
                  secret_credential: secret_credential,
                  raw_secret_credential: raw_secret_credential.to_s,
                )
              else
                verified = secret_credential.verify_for_secret_credential_sign_in!(raw_secret_credential.to_s)
                SecretVerificationResult.new(
                  secret_credential: verified ? secret_credential : nil,
                  reason: verified ? :success : :secret_credential_mismatch,
                  details: { secret_credential_id: secret_credential.id },
                )
              end

            unless verification.secret_credential
              return SecretVerificationResult.new(
                reason: verification.reason || :secret_credential_mismatch,
                details: verification.details.presence || { secret_credential_id: secret_credential.id },
              )
            end

            SecretVerificationResult.new(secret_credential: secret_credential, reason: :success)
          end

          def process_standard_login(staff)
            pt = signed_pt_param
            result = establish_signed_in_session!(
              staff, pt: pt, ri: current_region_identifier, auth_method: "secret_credential",
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
                notice: t("sign.org.authentication.secret_credential.create.success"),
              )
            else
              render_failed_login(sign_in_result.status)
            end
          end

          def render_failed_login(reason)
            @secret_credential_form ||= SecretLoginForm.new
            @secret_credential_form.errors.add(:base, invalid_secret_credential_message)

            staff = find_staff_by_public_id(@secret_credential_form.identifier)

            Rails.logger.info(
              JitLogEvent.format(
                "sign.org.authentication.secret_credential.failed",
                reason: reason,
                identifier_present: @secret_credential_form.identifier.present?,
                identifier_type: "public_id",
                staff_id: staff&.id,
                ip: request.remote_ip,
                ri: current_region_identifier,
                errors: @secret_credential_form.errors.full_messages,
              ),
            )

            SignRiskEmitter.emit("auth_failed", staff_id: staff&.id) if staff

            render :new, status: :unprocessable_content, formats: :html
          end

          def invalid_secret_credential_message
            t("sign.org.authentication.secret_credential.create.invalid")
          end

          def secret_credential_params
            params.fetch(:secret_credential_login_form, {}).permit(:identifier, :secret_credential_value)
          end

          def minimum_response_budget_enabled?
            action_name == "create"
          end
        end
      end
    end
  end
end
