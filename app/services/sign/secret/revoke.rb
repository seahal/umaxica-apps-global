# typed: false
# frozen_string_literal: true

module Sign
  module Secret
    class Revoke
      Result = Struct.new(:secret_credential, keyword_init: true)

      def self.call(secret_credential:, now: Time.current)
        new(secret_credential: secret_credential, now: now).call
      end

      def initialize(secret_credential:, now:)
        @secret_credential = secret_credential
        @now = now
      end

      def call
        @secret_credential.with_lock do
          @secret_credential.reload
          @secret_credential.revoked_at = @now if @secret_credential.respond_to?(:revoked_at=)
          @secret_credential.discarded_at = @now if @secret_credential.respond_to?(:discarded_at=)
          @secret_credential.save!
        end

        RecordEvent.call(event_name: "secret.revoked", secret_credential: @secret_credential)
        Result.new(secret_credential: @secret_credential)
      end
    end
  end
end
