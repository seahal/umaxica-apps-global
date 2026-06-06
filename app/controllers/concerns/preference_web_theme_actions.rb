# typed: false
# frozen_string_literal: true

module PreferenceWebThemeActions
  extend ActiveSupport::Concern

  def show
    render json: { theme: current_color_theme }, status: :ok
  end

  def update
    theme = apply_theme_update_from_request!
    render json: { theme: theme || current_color_theme }, status: :ok
  end
end
