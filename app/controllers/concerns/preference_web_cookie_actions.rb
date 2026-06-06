# typed: false
# frozen_string_literal: true

module PreferenceWebCookieActions
  extend ActiveSupport::Concern

  def show
    render json: cookie_consent_state, status: :ok
  end

  def update
    unless apply_consented_update_from_request!
      render json: { error: "missing_preference_access_token" }, status: :unauthorized
      return
    end

    render json: cookie_consent_state, status: :ok
  end
end
