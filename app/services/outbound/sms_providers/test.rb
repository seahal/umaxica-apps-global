# typed: false
# frozen_string_literal: true

module Outbound
  module SmsProviders
    class Test
      def send_message(to:, title:, body:)
        raise ArgumentError, "Phone number is required" if to.blank?
        raise ArgumentError, "Message is required" if body.blank?

        Outbound::ProviderResponse.accepted(
          provider: :test,
          provider_reference: "test-provider-reference",
        )
      end
    end
  end
end
