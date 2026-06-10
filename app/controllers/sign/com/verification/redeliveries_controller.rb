# typed: false
# frozen_string_literal: true

# Dedicated OTP redelivery (resend) endpoint for step-up email verification (com surface).
# The `resend` action was split out of Sign::Com::Verification::EmailsController into this
# RESTful redelivery resource: POST /verification/emails/:email_id/redelivery.
# It reuses the parent's resend flow; the route exposes the email nonce as :email_id,
# which the parent logic reads as params[:id].
class Sign::Com::Verification::RedeliveriesController < ::Sign::Com::Verification::EmailsController
  AUTHENTICATION_MODE = :private

  before_action :set_verification_navigation_context

  def create
    params[:id] = params[:email_id]
    resend
  end
end
