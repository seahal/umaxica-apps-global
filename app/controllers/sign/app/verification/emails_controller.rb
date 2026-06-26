# typed: false
# frozen_string_literal: true

class Sign::App::Verification::EmailsController < ::Sign::App::Verification::BaseController
  AUTHENTICATION_MODE = :private

  skip_before_action :enforce_step_up_prereqs!, only: %i(edit update)
  before_action :set_verification_navigation_context, only: %i(edit update resend)

  def new
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_get!
    return unless require_method_available!(:email_otp)

    unless send_email_otp!
      render :new, status: :unprocessable_content
      return
    end

    nonce = ensure_email_nonce!
    redirect_to(
      edit_sign_app_verification_email_path(
        nonce,
        ri: params[:ri],
        scope: current_step_up_scope,
        pt: current_step_up_pt_param,
      ),
    )
  end

  def edit
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_get!
    return unless require_email_nonce!

    return if email_otp_session_active?

    render :new, status: :unprocessable_content unless send_email_otp!
  end

  def create
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_post!
    return unless require_method_available!(:email_otp)

    unless send_email_otp!
      render :new, status: :unprocessable_content
      return
    end

    nonce = ensure_email_nonce!
    redirect_to(
      edit_sign_app_verification_email_path(
        nonce,
        ri: params[:ri],
        scope: current_step_up_scope,
        pt: current_step_up_pt_param,
      ),
    )
  end

  def update
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_post!
    return unless require_email_nonce!

    if verify_email_otp!
      consume_step_up_session!(method: :email_otp)
    else
      record_failed_step_up_attempt!(:email_otp)
      render :edit, status: :unprocessable_content
    end
  end

  def resend
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_post!
    return unless require_email_nonce!

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

  private

  def require_email_nonce!
    rs = current_step_up_session
    expected_nonce = current_email_otp_session_data&.fetch("nonce", nil)
    if rs.present? && expected_nonce.present? && params[:id] == expected_nonce
      return true
    end

    safe_redirect_to(
      sign_app_verification_path(verification_recovery_redirect_params),
      fallback: sign_app_verification_path(ri: params[:ri]),
      alert: I18n.t("auth.step_up.invalid_request"),
    )
    false
  end

  def set_verification_navigation_context
    @verification_scope = incoming_scope.presence || current_step_up_scope
    @verification_pt = incoming_pt.presence || current_step_up_pt_param
  end

  def verification_email_edit_path
    edit_sign_app_verification_email_path(
      params[:id],
      ri: params[:ri],
      scope: @verification_scope,
      pt: @verification_pt,
    )
  end
end
