# typed: false
# frozen_string_literal: true

module Outbound
  Result =
    Data.define(:accepted, :channel, :provider_message_id, :error) do
      def self.accepted(channel:, provider_message_id: nil)
        new(accepted: true, channel: channel, provider_message_id: provider_message_id, error: nil)
      end

      def self.rejected(channel:, error:)
        new(accepted: false, channel: channel, provider_message_id: nil, error: error)
      end

      def accepted? = accepted
    end
end
