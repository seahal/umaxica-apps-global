# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class RestrictedSessionGuardTest < ActionDispatch::IntegrationTest
  class DummyController
    include RestrictedSessionGuard

    attr_reader :request, :session

    def initialize
      @request = Struct.new(:path, :request_method, :remote_ip).new("/test", "GET", "127.0.0.1")
      @session = nil
    end

    def current_session
      @session
    end

    def current_session_restricted?
      @session&.restricted?
    end
  end

  setup do
    @controller = DummyController.new
  end

  test "BLOCKED_MESSAGE is set correctly" do
    assert_equal "きんそくじこうです", RestrictedSessionGuard::BLOCKED_MESSAGE
  end
end
