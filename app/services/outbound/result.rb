# typed: false
# frozen_string_literal: true

module Outbound
  Result =
    Data.define(:accepted, :channel, :delivery_id, :error) do
      def self.accepted(channel:, delivery_id: nil)
        new(accepted: true, channel: channel, delivery_id: delivery_id, error: nil)
      end

      def self.rejected(channel:, error:)
        new(accepted: false, channel: channel, delivery_id: nil, error: error)
      end

      def accepted? = accepted
    end
end
