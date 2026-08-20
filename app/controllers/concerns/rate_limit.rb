# typed: false
# frozen_string_literal: true

# Thin helper for Rails-native ActionController::RateLimiting declarations.
module RateLimit
  extend ActiveSupport::Concern

  include ProblemDetailsRendering

  # Constant partition key from draft-ietf-httpapi-ratelimit-headers. The draft requires a partition
  # name; naming the rule that actually fired would tell a caller how to reshape traffic to evade it,
  # so every rejection reports the same opaque partition. Which rule fired is already carried by the
  # `rate_limit.action_controller` notification, which is where operators read it.
  RATE_LIMIT_PARTITION = "default"

  class_methods do
    def rate_limit_store
      Rails.configuration.x.rate_limit.fetch(:store)
    end
  end

  private

  # `RateLimit-Policy` is deliberately absent: it carries the quota and window, and neither is
  # available here. Emitting a fabricated policy would be a silent falsehood about the limit, so the
  # header is omitted until the quota is threaded through. `Retry-After` (RFC 9110 10.2.3, Internet
  # Standard) remains the authoritative retry signal; see adr/api-versioning-and-client-conventions.md.
  def render_rate_limited(retry_after:)
    retry_after_seconds = retry_after.to_i

    response.headers["Retry-After"] = retry_after_seconds.to_s
    response.headers["RateLimit"] = %(#{RATE_LIMIT_PARTITION.inspect};r=0;t=#{retry_after_seconds})

    respond_to do |format|
      format.json { render_problem(:rate_limited, detail: I18n.t("errors.rate_limit.exceeded")) }
      format.html do
        render plain: I18n.t("errors.rate_limit.exceeded"),
               content_type: "text/plain",
               status: :too_many_requests
      end
    end
  end
end
