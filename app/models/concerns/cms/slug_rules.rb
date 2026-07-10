# typed: false
# frozen_string_literal: true

module Cms
  module SlugRules
    FORMAT = /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/
    STATES = %w(reserved canonical redirect).freeze

    module_function

    def valid_format?(slug) = FORMAT.match?(slug.to_s)

    def timestamps_valid?(state:, canonicalized_at:, redirected_at:)
      case state
      when "reserved" then canonicalized_at.nil? && redirected_at.nil?
      when "canonical" then canonicalized_at.present? && redirected_at.nil?
      when "redirect"
        canonicalized_at.present? && redirected_at.present? && redirected_at >= canonicalized_at
      else false
      end
    end
  end
end
