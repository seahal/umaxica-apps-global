# typed: false
# frozen_string_literal: true

module Redirects
  TargetResult = Data.define(:kind, :source, :value, :failure_reason, :unsafe_value_digest) do
    def self.ok(kind:, source:, value:)
      new(kind: kind, source: source, value: value, failure_reason: nil, unsafe_value_digest: nil)
    end

    def self.failure(kind:, source:, reason:, unsafe_value: nil)
      new(
        kind: kind,
        source: source,
        value: nil,
        failure_reason: reason.to_s,
        unsafe_value_digest: digest_unsafe_value(unsafe_value),
      )
    end

    def ok?
      failure_reason.blank? && value.present?
    end

    def self.digest_unsafe_value(value)
      return nil if value.nil?

      OpenSSL::Digest::SHA256.hexdigest(value.to_s)
    end
  end
end
