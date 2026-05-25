# typed: false
# frozen_string_literal: true

module Sign
  module App
    module In
      class SecretsController < GuestController
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

        class MfaSecretForm
          include ActiveModel::Model

          attr_accessor :secret_value, :turnstile_response

          validates :secret_value, presence: true

          def self.model_name
            ActiveModel::Name.new(self, nil, "mfa_secret_form")
          end
        end

        SecretVerificationResult = Struct.new(:secret, :reason, :details, keyword_init: true)

        MFA_USER_SESSION_KEY = :mfa_user_id

        def new
          if mfa_user
            @secret_form = MfaSecretForm.new
            @secret_hints = active_secret_hints_for(mfa_user)
          else
            @secret_form = SecretLoginForm.new
          end
        end

        def create
          if mfa_user
            handle_mfa_login
          else
            handle_standard_login
          end
        end

        def handle_mfa_login
          @secret_form = MfaSecretForm.new(mfa_secret_params)
          @secret_form.turnstile_response = turnstile_response_param
          unless @secret_form.valid?
            return render_failed_login(
              reason: :form_invalid,
              user: mfa_user,
              details: { errors: @secret_form.errors.full_messages },
            )
          end
          unless cloudflare_turnstile_validation["success"]
            return render_failed_login(reason: :turnstile_failed, user: mfa_user)
          end

          user = mfa_user
          verification = verify_secret_for_sign_in(user: user, raw_secret: @secret_form.secret_value)

          if verification.secret
            handle_successful_mfa(user, verification.secret)
          else
            handle_failed_mfa(user, verification.reason, verification.details)
          end
        rescue StandardError => e
          report_authentication_error(e, flow: "mfa_secret")
          render_failed_login(reason: :internal_error, user: mfa_user, details: { error_class: e.class.name })
        end

        def handle_standard_login
          @secret_form = SecretLoginForm.new(secret_params)
          @secret_form.turnstile_response = turnstile_response_param
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

          user = find_user_by_identifier(@secret_form.identifier)
          return render_session_limit_hard_reject if session_limit_hard_reject_for?(user)

          verification = verify_secret_for_sign_in(user: user, raw_secret: @secret_form.secret_value)

          if user && verification.secret
            process_standard_login(user)
          else
            failure_reason = verification.reason || :identifier_not_found
            render_failed_login(
              reason: failure_reason,
              identifier: @secret_form.identifier,
              user: user,
              details: verification.details,
            )
          end
        rescue StandardError => e
          report_authentication_error(e, flow: "secret")
          render_failed_login(
            reason: :internal_error,
            identifier: @secret_form&.identifier,
            details: { error_class: e.class.name },
          )
        end

        def handle_successful_mfa(user, secret)
          Rails.logger.info(
            LogEvent.format(
              "authentication.mfa.succeeded", user_id: user.id, ip_address: request.remote_ip,
                                              method: "secret", secret_id: secret.id,
            ),
          )
          clear_mfa_session!
          result = finalize_mfa_login!(user)
          case result[:status]
          when :session_limit_hard_reject
            render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
          when :restricted
            redirect_to(result[:redirect_path], notice: I18n.t("sign.app.in.session.restricted_notice"))
          when :success
            redirect_to_sign_in_sequence!(
              rt: result[:redirect_path],
              notice: t("sign.app.authentication.secret.create.success"),
            )
          else
            render_failed_login(reason: result[:status], user: user)
          end
        end

        def handle_failed_mfa(user, reason, details = {})
          Rails.logger.info(
            LogEvent.format(
              "authentication.totp.failed", user_id: user&.id, ip_address: request.remote_ip,
                                            method: "secret",
            ),
          )
          @secret_hints = active_secret_hints_for(user) if user
          render_failed_login(reason: reason, user: user, details: details)
        end

        def process_standard_login(user)
          result = establish_signed_in_session!(
            user, rt: nil, ri: params[:ri], auth_method: "secret",
          )
          sign_in_result = sign_in_result_from_session_result(result, actor: user)
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

        private

        def turnstile_response_param
          params.expect("cf-turnstile-response").to_s
        end

        def mfa_user
          return @mfa_user if defined?(@mfa_user)

          user_id = session[MFA_USER_SESSION_KEY]
          # Ensure user_id is clearly present before querying
          if user_id.blank?
            @mfa_user = nil
            return nil
          end

          @mfa_user = Client.find_by(id: user_id)
        end

        def clear_mfa_session!
          session[MFA_USER_SESSION_KEY] = nil
        end

        # Secret sign-in uses the most recently issued eligible secret.
        # This keeps verification deterministic and logging easier to reason about.
        def verify_secret_for_sign_in(user:, raw_secret:)
          return SecretVerificationResult.new(reason: :identifier_not_found, details: {}) unless user

          return SecretVerificationResult.new(
            reason: :verified_pii_missing,
            details: {},
          ) unless user.has_verified_pii?

          latest_secret = user.client_secrets.order(created_at: :desc).first
          return SecretVerificationResult.new(reason: :secret_not_found, details: {}) unless latest_secret

          latest_eligible_secret = user.client_secrets.allowed_for_secret_sign_in.order(created_at: :desc).first
          unless latest_eligible_secret
            return SecretVerificationResult.new(
              reason: :secret_expired,
              details: {
                latest_secret_id: latest_secret.id,
                latest_status_id: latest_secret.user_secret_status_id,
                latest_kind_id: latest_secret.user_secret_kind_id,
              },
            )
          end
          unless latest_eligible_secret.usable_for_secret_sign_in?
            return SecretVerificationResult.new(
              reason: :secret_expired,
              details: {
                secret_id: latest_eligible_secret.id,
                uses_remaining: latest_eligible_secret.uses_remaining,
                expires_at: latest_eligible_secret.expires_at,
              },
            )
          end

          unless latest_eligible_secret.verify_for_secret_sign_in!(raw_secret.to_s)
            return SecretVerificationResult.new(
              reason: :secret_mismatch,
              details: { secret_id: latest_eligible_secret.id },
            )
          end

          audit_recovery_code_used!(user, latest_eligible_secret) if latest_eligible_secret.recovery_secret?
          SecretVerificationResult.new(
            secret: latest_eligible_secret,
            reason: :success,
            details: { secret_id: latest_eligible_secret.id },
          )
        end

        def active_secret_hints_for(user)
          user.client_secrets
            .allowed_for_secret_sign_in
            .order(created_at: :desc)
            .limit(10)
            .filter_map { |s| s.name.to_s.first(4) if s.usable_for_secret_sign_in? }
        end

        def secret_params
          params.fetch(:secret_login_form, {}).permit(
            :identifier,
            :secret_value,
          )
        end

        def mfa_secret_params
          params.fetch(:mfa_secret_form, {}).permit(:secret_value)
        end

        def invalid_secret_message
          t("sign.app.authentication.secret.create.invalid")
        end

        def report_authentication_error(error, flow:)
          Rails.logger.error(
            LogEvent.format(
              "sign.authentication.secret.error",
              flow: flow,
              error_class: error.class.name,
              message: error.message,
              user_id: mfa_user&.id,
              ip: request.remote_ip,
              exception: error,
            ),
          )
        end

        def render_failed_login(reason:, identifier: nil, user: nil, details: {})
          @secret_form.errors.add(:base, invalid_secret_message)

          # Detailed failure logging (failure_reason=...) as requested
          Rails.logger.info(
            LogEvent.format(
              "sign.authentication.secret.failed",
              reason: reason,
              identifier_type: detect_identifier_type(identifier.to_s),
              identifier_present: identifier.present?,
              user_id: user&.id,
              ip: request.remote_ip,
              errors: @secret_form.errors.full_messages,
              details: details,
            ),
          )

          Sign::Risk::Emitter.emit("auth_failed", user_id: user&.id) if user

          render_new_with_unprocessable_entity
        end

        def render_new_with_unprocessable_entity
          render :new, status: :unprocessable_content, formats: :html
        end

        def audit_recovery_code_used!(user, secret)
          ChronicleRecord.connected_to(role: :writing) do
            ClientChronicleEvent.find_or_create_by!(id: ClientChronicleEvent::RECOVERY_CODE_USED)
            ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
          end

          ClientChronicle.create!(
            actor_type: "Client",
            actor_id: user.id,
            event_id: ClientChronicleEvent::RECOVERY_CODE_USED,
            subject_id: secret.id.to_s,
            subject_type: "ClientSecret",
            occurred_at: Time.current,
          )
        end
      end
    end
  end
end
