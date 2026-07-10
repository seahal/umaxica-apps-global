# typed: false
# frozen_string_literal: true

class Auth::Org::Verification::CancellationsController < ::Auth::Org::Verification::BaseController
  include SignVerificationCancellation

  AUTHENTICATION_MODE = :private

  private

  def verification_cancellation_fallback_path
    auth_org_settings_path(ri: params[:ri])
  end
end
