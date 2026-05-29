# typed: false
# frozen_string_literal: true

require "json"

module Jit
  module Security
    # Fetches SECRET_KEY_BASE from AWS Secrets Manager for production.
    # Expected JSON format in Secrets Manager:
    #   { "current": "the_current_key", "previous": ["old_key_1", "old_key_2"] }
    #
    # Outside production, falls back to ENV or Rails credentials.
    module SecretKeyBaseProvider
      module_function

      # Returns { current: String, previous: [String] }
      def fetch
        if use_secrets_manager?
          fetch_from_secrets_manager
        else
          fetch_from_local
        end
      end

      def use_secrets_manager?
        Rails.env.production? && secret_id.present?
      end

      def secret_id
        ENV["SECRET_KEY_BASE_SECRET_ID"]
      end

      def fetch_from_secrets_manager
        require "aws-sdk-secretsmanager"

        client = Aws::SecretsManager::Client.new(
          region: ENV.fetch("AWS_REGION", "ap-northeast-1"),
        )

        response = client.get_secret_value(secret_id: secret_id)
        parsed = JSON.parse(response.secret_string)

        current = parsed.fetch("current")
        previous = Array(parsed["previous"])

        { current: current, previous: previous }
      rescue Aws::SecretsManager::Errors::ServiceError, JSON::ParserError, KeyError => e
        Rails.logger.error(
          Jit::LogEvent.format(
            "secret_key_base.fetch_failed",
            error_class: e.class.name,
            message: e.message,
          ),
        )
        raise
      end

      def fetch_from_local
        current = ENV["SECRET_KEY_BASE"] || Rails.application.credentials.secret_key_base
        previous = parse_local_previous

        { current: current, previous: previous }
      end

      def parse_local_previous
        raw = ENV["SECRET_KEY_BASE_PREVIOUS"]
        return [] if raw.blank?

        JSON.parse(raw)
      rescue JSON::ParserError
        [raw]
      end
    end
  end
end
