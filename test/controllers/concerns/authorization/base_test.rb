# typed: false
# frozen_string_literal: true

require "test_helper"

module Authorization
  class BaseTest < ActiveSupport::TestCase
    test "legacy request authorization hook fails closed" do
      controller = Class.new { include Authorization::Base }.new

      error = assert_raises(RuntimeError) { controller.send(:authorize_request!) }

      assert_match "disabled", error.message
    end
  end
end
