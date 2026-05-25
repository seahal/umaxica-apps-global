# typed: false
# frozen_string_literal: true

module Sign
  module EmailOtpVerificationSupport
    extend ActiveSupport::Concern

    EMAIL_OTP_RESEND_COOLDOWN = StepUp::Cooldowns::WINDOWS.fetch(:email_otp)

    private

    def verification_params
      params.fetch(:verification, {}).permit(
        :code, :challenge_id, :credential_json, :scope, :return_to,
        :rt,
      )
    end

    def email_otp_session_active?
      current_step_up_session.present? && Rails.cache.exist?(email_otp_cache_key)
    end

    def ensure_email_nonce!
      Rails.cache.fetch(
        email_nonce_cache_key,
        expires_in: [current_step_up_session.discarded_at - Time.current, 0].max,
      ) do
        SecureRandom.urlsafe_base64(16)
      end
    end

    def current_step_up_scope
      current_step_up_session&.scope
    end

    def current_step_up_return_to_param
      return_to = current_step_up_session&.return_to
      return if return_to.blank?

      issue_step_up_rt(return_to)
    end

    def verification_recovery_redirect_params
      attrs = { ri: params[:ri] }

      scope = incoming_scope
      attrs[:scope] = scope if scope.present?

      return_to = incoming_return_to
      attrs[:return_to] = return_to if return_to.present?

      attrs
    end

    def restore_step_up_session_from_params!
      scope = incoming_scope
      return_to = incoming_return_to
      return false if scope.blank? || return_to.blank?

      start_step_up_session!(scope: scope, return_to_param: return_to)
      true
    rescue ActionController::BadRequest
      false
    end

    def incoming_scope
      verification_params[:scope].to_s.presence ||
        request_parameters["scope"].to_s.presence
    end

    def incoming_return_to
      verification_params[:return_to].to_s.presence ||
        verification_params[:rt].to_s.presence ||
        request_parameters["return_to"].to_s.presence ||
        request_parameters["rt"].to_s.presence
    end

    def request_parameters
      return request.parameters if respond_to?(:request, true) && request.respond_to?(:parameters)
      return params if respond_to?(:params, true)

      {}
    end

    def clear_step_up_state!
      Rails.cache.delete(email_otp_cache_key) if current_step_up_session.present?
    end

    def verify_email_otp!
      code = verification_params[:code].to_s
      unless code.match?(/\A\d{6}\z/)
        @verification_errors = [I18n.t("sign.app.verification.errors.invalid_code")]
        return false
      end

      data = Rails.cache.read(email_otp_cache_key)
      unless data
        @verification_errors = [I18n.t("sign.app.verification.errors.resend_required")]
        return false
      end

      if current_step_up_session.discarded_at <= Time.current
        @verification_errors = [I18n.t("sign.app.verification.errors.code_expired")]
        return false
      end

      ok = verify_hotp_code(secret: data["secret"], counter: data["counter"], pass_code: code)
      unless ok
        @verification_errors = [I18n.t("sign.app.verification.errors.incorrect_code")]
        return false
      end

      true
    end

    def email_otp_cache_key
      "step_up_session:#{current_step_up_session.id}:email_otp"
    end

    def email_nonce_cache_key
      rs = current_step_up_session
      key_id = rs.respond_to?(:id) ? rs.id : rs.hash
      "step_up_session:#{key_id}:email_nonce"
    end

    def email_otp_resend_cache_key
      "step_up_session:#{current_step_up_session.id}:email_otp_resend"
    end

    def email_otp_resend_rate_limited?
      Rails.cache.exist?(email_otp_resend_cache_key)
    end

    def stamp_email_otp_resend!
      Rails.cache.write(
        email_otp_resend_cache_key,
        Time.current.to_i,
        expires_in: EMAIL_OTP_RESEND_COOLDOWN,
      )
    end
  end
end
