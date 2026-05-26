# typed: false
# frozen_string_literal: true

module Redirects
  class PathTargetResolver
    CONTROL_CHAR_PATTERN = /[\x00-\x1F\x7F]/
    ENCODED_CONTROL_PATTERN = /%(?:0[0-9a-f]|1[0-9a-f]|7f)/i
    ENCODED_HOST_ESCAPE_PATTERN = /%(?:2f|5c)/i

    def self.call(value, source: :raw_pt)
      new(value, source: source).call
    end

    def initialize(value, source:)
      @value = value
      @source = source
    end

    def call
      return failure(:blank) unless value.is_a?(String) && value.present?
      return failure(:control_char) if value.match?(CONTROL_CHAR_PATTERN)
      return failure(:encoded_control_char) if value.match?(ENCODED_CONTROL_PATTERN)
      return failure(:encoded_host_escape) if value.match?(ENCODED_HOST_ESCAPE_PATTERN)
      return failure(:backslash) if value.include?("\\")

      uri = URI.parse(value)
      return failure(:scheme) if uri.scheme.present?
      return failure(:host) if uri.host.present?
      return failure(:userinfo) if uri.userinfo.present?
      return failure(:fragment) if uri.fragment.present?

      path = uri.path
      return failure(:blank_path) if path.blank?
      return failure(:relative_path) unless path.start_with?("/")
      return failure(:protocol_relative) if path.start_with?("//")

      Redirects::TargetResult.ok(kind: :pt, source: source, value: uri.query.present? ? "#{path}?#{uri.query}" : path)
    rescue URI::InvalidURIError
      failure(:invalid_uri)
    end

    private

    attr_reader :value, :source

    def failure(reason)
      Redirects::TargetResult.failure(kind: :pt, source: source, reason: reason, unsafe_value: value)
    end
  end
end
