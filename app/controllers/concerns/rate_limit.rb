# typed: false
# frozen_string_literal: true

# Thin helper for Rails-native ActionController::RateLimiting declarations.
module RateLimit
  extend ActiveSupport::Concern

  class_methods do
    def rate_limit_store
      Rails.configuration.x.rate_limit.fetch(:store)
    end
  end

  private

  def render_rate_limited(rule_name:, retry_after:)
    retry_after_seconds = retry_after.to_i

    response.headers["X-RateLimit-Layer"] = "rails"
    response.headers["X-RateLimit-Rule"] = rule_name.to_s
    response.headers["Retry-After"] = retry_after_seconds.to_s

    payload = {
      error: "rate_limited",
      rule: rule_name.to_s,
      message: I18n.t("errors.rate_limit.exceeded"),
      retry_after: retry_after_seconds,
    }

    respond_to do |format|
      format.json { render json: payload, status: :too_many_requests }
      format.html { render plain: payload.fetch(:message), status: :too_many_requests }
    end
  end
end
