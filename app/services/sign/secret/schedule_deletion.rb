# typed: false
# frozen_string_literal: true

module Sign
  module Secret
    class ScheduleDeletion
      Result = Struct.new(:secret_credential, keyword_init: true)

      def self.call(secret_credential:, purge_after:, now: Time.current)
        new(secret_credential: secret_credential, purge_after: purge_after, now: now).call
      end

      def initialize(secret_credential:, purge_after:, now:)
        @secret_credential = secret_credential
        @purge_after = purge_after
        @now = now
      end

      def call
        @secret_credential.discard_now!(purge_after: @purge_after, now: @now)
        RecordEvent.call(event_name: "secret.scheduled_deletion", secret_credential: @secret_credential)
        Result.new(secret_credential: @secret_credential)
      end
    end
  end
end
