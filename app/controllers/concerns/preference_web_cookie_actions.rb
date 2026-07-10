# typed: false
# frozen_string_literal: true

module PreferenceWebCookieActions
  extend ActiveSupport::Concern

  def show
    render json: { show_banner: show_banner? }, status: :ok
  end

  def update
    unless apply_consented_update_from_request!
      render json: { error: "missing_preference_access_token" }, status: :unauthorized
      return
    end

    head :no_content
  end
end
