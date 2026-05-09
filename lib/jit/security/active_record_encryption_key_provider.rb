# typed: false
# frozen_string_literal: true

require "json"

module Jit
  module Security
    # Centralized key resolution for Active Record encryption rotation.
    # Uses Rails.app.creds (ENV -> credentials) for unified lookup.
    module ActiveRecordEncryptionKeyProvider
      module_function

      # Returns { current: String, previous: [String] }.
      def fetch
        fetch_from_local
      end

      def fetch_from_local
        current = Rails.app.creds.require(:ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY)
        previous = parse_local_previous

        { current: current, previous: previous }
      end

      def parse_local_previous
        raw = Rails.app.creds.option(:ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS)
        return [] if raw.blank?

        Array(JSON.parse(raw))
      rescue JSON::ParserError
        [raw]
      end
    end
  end
end
