# typed: false
# frozen_string_literal: true

module SignEmailOtpRedeliveryEndpoint
  extend ActiveSupport::Concern

  private

  def resend_email_otp_redelivery
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_post!
    return unless require_email_nonce_for_redelivery!

    if email_otp_resend_rate_limited?
      redirect_to(
        verification_email_edit_path,
        alert: t("otp.resend.too_soon"),
      )
      return
    end

    if send_email_otp!
      stamp_email_otp_resend!
      redirect_to(
        verification_email_edit_path,
        notice: t("otp.resend.sent"),
      )
    else
      redirect_to(
        verification_email_edit_path,
        alert: t("otp.resend.failed"),
      )
    end
  end

  def require_email_nonce_for_redelivery!
    rs = current_step_up_session
    expected_nonce = current_email_otp_session_data&.fetch("nonce", nil)
    return true if rs.present? && expected_nonce.present? && params[:id] == expected_nonce

    safe_redirect_to(
      verification_recovery_path,
      fallback: verification_recovery_fallback_path,
      alert: I18n.t("auth.step_up.invalid_request"),
    )
    false
  end

  def set_verification_redelivery_navigation_context
    @verification_scope = incoming_scope.presence || current_step_up_scope
    @verification_pt = incoming_pt.presence || current_step_up_pt_param
  end
end
