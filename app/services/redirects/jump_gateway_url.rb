# typed: false
# frozen_string_literal: true

module Redirects
  class JumpGatewayUrl
    TOKEN_PATTERN = /\A[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\z/

    def self.call(token, source: :jump_rt)
      new(token, source: source).call
    end

    def initialize(token, source:)
      @token = token
      @source = source
    end

    def call
      return failure(:blank_token) if token.blank?
      return failure(:control_char) if token.match?(/[\x00-\x1F\x7F]/)
      return failure(:malformed_token) unless token.match?(TOKEN_PATTERN)

      uri = URI.parse(gateway_origin)
      return failure(:invalid_origin) if uri.scheme.blank? || uri.host.blank?
      return failure(:https_required) unless uri.scheme == "https" || local_origin_allowed?(uri)

      uri.path = "/"
      uri.query = URI.encode_www_form("rt" => token)
      uri.fragment = nil
      uri.user = nil
      uri.password = nil

      Redirects::TargetResult.ok(kind: :xt, source: source, value: uri.to_s)
    rescue URI::InvalidURIError
      failure(:invalid_uri)
    end

    private

    attr_reader :token, :source

    def gateway_origin
      ENV.fetch("JUMP_GATEWAY_URL", "https://jump.umaxica.net")
    end

    def local_origin_allowed?(uri)
      Rails.env.local? && uri.scheme == "http" &&
        (uri.host == "localhost" || uri.host.end_with?(".localhost"))
    end

    def failure(reason)
      Redirects::TargetResult.failure(kind: :xt, source: source, reason: reason, unsafe_value: token)
    end
  end
end
