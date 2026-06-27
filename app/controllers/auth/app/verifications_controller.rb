# typed: false
# frozen_string_literal: true

class Auth::App::VerificationsController < ::Auth::App::Verification::BaseController
  include SignVerificationEntry

  AUTHENTICATION_MODE = :private

  private

  def verification_success_notice_key
    "sign.app.verification.success.complete"
  end

  def verification_invalid_request_redirect_path(ri:)
    auth_app_settings_path(ri: ri)
  end
end
