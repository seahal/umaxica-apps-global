# typed: false
# frozen_string_literal: true

class Auth::App::Verification::CancellationsController < ::Auth::App::Verification::BaseController
  include SignVerificationCancellation

  AUTHENTICATION_MODE = :private

  private

  def verification_cancellation_fallback_path
    sign_app_settings_path(ri: params[:ri])
  end
end
