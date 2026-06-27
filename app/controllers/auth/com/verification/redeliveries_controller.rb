# typed: false
# frozen_string_literal: true

# Dedicated OTP redelivery (resend) endpoint for step-up email verification (com surface).
# The `resend` action was split out of Auth::Com::Verification::EmailsController into this
# RESTful redelivery resource: POST /verification/emails/:email_id/redelivery.
# It reuses the parent's resend flow; the route exposes the email nonce as :email_id,
# which the parent logic reads as params[:id].
class Auth::Com::Verification::RedeliveriesController < ::Auth::Com::Verification::BaseController
  include ::SignEmailOtpRedeliveryEndpoint

  AUTHENTICATION_MODE = :private

  before_action :set_verification_redelivery_navigation_context

  def create
    params[:id] = params[:email_id]
    resend_email_otp_redelivery
  end

  private

  def verification_email_edit_path
    edit_auth_com_verification_email_path(
      params[:id],
      ri: params[:ri],
      scope: @verification_scope,
      pt: @verification_pt,
    )
  end

  def verification_recovery_path
    auth_com_verification_path(verification_recovery_redirect_params)
  end

  def verification_recovery_fallback_path
    auth_com_verification_path(ri: params[:ri])
  end
end
