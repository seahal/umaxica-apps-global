# typed: false
# frozen_string_literal: true

require "test_helper"

module Outbound
  module SmsProviders
    class TestTest < ActiveSupport::TestCase
      test "raises ArgumentError when phone number is blank" do
        provider = Outbound::SmsProviders::Test.new

        assert_raises(ArgumentError) do
          provider.send_message(to: "", title: "Title", body: "Hello")
        end

        assert_raises(ArgumentError) do
          provider.send_message(to: nil, title: "Title", body: "Hello")
        end
      end

      test "raises ArgumentError when message body is blank" do
        provider = Outbound::SmsProviders::Test.new

        assert_raises(ArgumentError) do
          provider.send_message(to: "+1234567890", title: "Title", body: "")
        end

        assert_raises(ArgumentError) do
          provider.send_message(to: "+1234567890", title: "Title", body: nil)
        end
      end

      test "returns accepted provider response" do
        provider = Outbound::SmsProviders::Test.new
        result = provider.send_message(to: "+1234567890", title: "Title", body: "Hello")

        assert_equal "test", result.provider
        assert_equal "test-provider-reference", result.provider_reference
        assert_kind_of ActiveSupport::TimeWithZone, result.accepted_at
      end
    end
  end
end
