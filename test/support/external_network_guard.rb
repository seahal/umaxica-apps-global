# typed: false
# frozen_string_literal: true

if Rails.env.test? && ENV["ALLOW_EXTERNAL_NETWORK_IN_TEST"] != "1"
  require "net/http"

  module ExternalNetworkGuard
    LOCAL_HOSTS = [
      "localhost",
      "127.0.0.1",
      "::1",
    ].freeze

    module_function

    def allowed_host?(host)
      normalized = host.to_s.downcase
      normalized.blank? ||
        LOCAL_HOSTS.include?(normalized) ||
        normalized.end_with?(".localhost")
    end

    def block!(target)
      raw_target = target.to_s
      uri = target.respond_to?(:hostname) ? target : URI(raw_target)
      host = uri.hostname || uri.host || raw_target.split(":").first
      return if allowed_host?(host)

      raise RuntimeError, "External network access is disabled in tests: #{raw_target}"
    rescue URI::InvalidURIError
      raise RuntimeError, "External network access is disabled in tests: #{target}"
    end
  end

  module NetHttpExternalNetworkGuard
    def request(request, body = nil, &)
      ExternalNetworkGuard.block!(address)
      super
    end

    def connect
      ExternalNetworkGuard.block!(address)
      super
    end
  end

  Net::HTTP.prepend(NetHttpExternalNetworkGuard)
end
