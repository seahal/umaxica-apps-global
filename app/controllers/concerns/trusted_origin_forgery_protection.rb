# typed: false
# frozen_string_literal: true

module TrustedOriginForgeryProtection
  extend ActiveSupport::Concern

  private

  def valid_request_origin?
    return true unless forgery_protection_origin_check

    origin = request.origin
    if origin == "null"
      raise ActionController::InvalidCrossOriginRequest,
            "The browser returned a null Origin header for an origin-protected request."
    end

    origin.nil? || origin == request.base_url || forgery_protection_trusted_origins.include?(origin)
  end
end
