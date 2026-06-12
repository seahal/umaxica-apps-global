# typed: false
# frozen_string_literal: true

module Sign
  module Secret
    class RecordEvent
      Result = Struct.new(:event_name, :secret_credential_id, :details, keyword_init: true)

      def self.call(event_name:, secret_credential:, details: {})
        new(event_name: event_name, secret_credential: secret_credential, details: details).call
      end

      def initialize(event_name:, secret_credential:, details:)
        @event_name = event_name
        @secret_credential = secret_credential
        @details = details
      end

      def call
        Rails.logger.info(
          JitLogEvent.format(
            "sign.secret.event",
            event_name: @event_name,
            secret_credential_id: @secret_credential&.id,
            details: @details.except(:raw_secret_credential),
          ),
        )

        Result.new(event_name: @event_name, secret_credential_id: @secret_credential&.id, details: @details)
      end
    end
  end
end
