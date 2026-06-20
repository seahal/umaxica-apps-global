# typed: false
# frozen_string_literal: true

class Sign::Org::Verification::CancellationsController < ::Sign::Org::Verification::BaseController
  include SignVerificationCancellation

  AUTHENTICATION_MODE = :private

  private

  def verification_cancellation_fallback_path
    sign_org_settings_path(ri: params[:ri])
  end
end
