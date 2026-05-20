# typed: false
# frozen_string_literal: true

require "test_helper"

module Outbound
  class EmailTest < ActiveSupport::TestCase
    test "accepts a common outbound message payload" do
      result = Email.call(to: "user@example.com", title: "Title", body: "Body")

      assert_predicate result, :accepted?
      assert_equal :email, result.channel
      assert_nil result.provider_message_id
      assert_nil result.error
    end
  end
end
