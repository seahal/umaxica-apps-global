# typed: false
# frozen_string_literal: true

module SignVerificationTotpActions
  extend ActiveSupport::Concern

  def new
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_get!

    nil unless require_method_available!(:totp)
  end

  def create
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_post!
    return unless require_method_available!(:totp)

    unless cloudflare_turnstile_stealth_validation["success"]
      @verification_errors = [t("turnstile_error")]
      render :new, status: :unprocessable_content
      return
    end

    if verify_totp!
      consume_step_up_session!(method: :totp)
    else
      record_failed_step_up_attempt!(:totp)
      render :new, status: :unprocessable_content
    end
  end
end
