# typed: false
# frozen_string_literal: true

class OutboundSmsProvidersTest
  def send_message(to:, title:, body:)
    raise ArgumentError, "Phone number is required" if to.blank?
    raise ArgumentError, "Message is required" if body.blank?
    raise ArgumentError, "Title must be a string or nil" unless title.nil? || title.is_a?(String)

    OutboundProviderResponse.accepted(
      provider: :test,
      provider_reference: "test-provider-reference",
    )
  end
end
