# typed: false
# frozen_string_literal: true

# Concern for standardized error response handling
# Provides common error handlers for Action Policy authorization failures
#
# Usage:
#   class ApplicationController < ActionController::Base
#     include SignErrorResponses
#     rescue_from ActionPolicy::Unauthorized, with: :handle_not_authorized
#   end
module SignErrorResponses
  extend ActiveSupport::Concern

  include CommonRedirect

  def handle_application_error(exception)
    respond_to do |format|
      format.html do
        flash[:alert] = exception.message
        safe_redirect_back_or_to("/")
      end
      format.json { render json: { error: exception.message }, status: exception.status_code }
      format.any { head exception.status_code }
    end
  end

  # Handles Action Policy authorization failures
  # Responds with JSON error for API requests, forbidden status for others
  #
  # @param exception [ActionPolicy::Unauthorized] The authorization error
  def handle_not_authorized(_exception = nil)
    respond_to do |format|
      format.json { render json: { error: I18n.t("errors.forbidden") }, status: :forbidden }
      format.any { head :forbidden }
    end
  end

  # Alias for user-facing authorization failures
  alias_method :user_not_authorized, :handle_not_authorized

  # Alias for staff-facing authorization failures
  alias_method :staff_not_authorized, :handle_not_authorized

  def handle_csrf_failure
    raise ActionController::InvalidCrossOriginRequest unless request.format.json?

    render json: { error: I18n.t("errors.invalid_authenticity_token") },
           status: :unprocessable_content
  end
end
