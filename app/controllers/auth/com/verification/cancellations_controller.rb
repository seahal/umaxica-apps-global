# typed: false
# frozen_string_literal: true

class Auth::Com::Verification::CancellationsController < ::Auth::Com::Verification::BaseController
  include SignVerificationCancellation

  AUTHENTICATION_MODE = :private

  private

  def verification_cancellation_fallback_path
    auth_com_settings_path(ri: params[:ri])
  end
end
