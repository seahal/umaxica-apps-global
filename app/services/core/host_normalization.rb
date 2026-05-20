# typed: false
# frozen_string_literal: true

require "uri"

module Core
  module HostNormalization
    module_function

    def normalize(value)
      return nil if value.blank?

      str = value.to_s.strip
      return nil if str.blank?

      host = parsed_host(str) || fallback_host(str)
      host&.downcase&.delete_suffix(".")
    end

    def parsed_host(str)
      candidate = str.match?(%r{\A[A-Za-z][A-Za-z0-9+\-.]*://}) ? str : "//#{str}"
      URI.parse(candidate).host.presence
    rescue URI::InvalidURIError
      nil
    end
    private_class_method :parsed_host

    def fallback_host(str)
      str.sub(%r{\Ahttps?://}i, "").split("/").first.to_s.split(":").first
    end
    private_class_method :fallback_host
  end
end
