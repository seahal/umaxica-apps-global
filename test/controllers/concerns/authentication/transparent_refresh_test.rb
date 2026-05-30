# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationTransparentRefreshHarnessController < ApplicationController
  include Authentication::Base

  def resource_type = "client"

  def resource_class = Client

  %i(transparent_refresh_access_token current_resource logged_in?).each do |method_name|
    next unless method_defined?(method_name) || private_method_defined?(method_name)
  end
  public

  method_name
end

module Authentication
  class TransparentRefreshTest < ActionDispatch::IntegrationTest
    def test_does_not_refresh_on_post_patch_put_delete
      %w(POST PATCH PUT DELETE).each do |method|
        controller = build_controller(method: method)
        controller.send(:cookies)[Authentication::Base::REFRESH_COOKIE_KEY] = "refresh-token"
        refresh_calls = 0
        controller.define_singleton_method(:refresh_access_token) do |_refresh_plain|
          refresh_calls += 1
          { user: Object.new }
        end

        controller.transparent_refresh_access_token

        assert_equal 0, refresh_calls, "#{method} must not transparently refresh"
        assert_nil controller.request.env[Auth::IoKeys::Env::AUTH_REFRESHED_FLAG]
      end
    end

    test "does not refresh json get requests" do
      controller = build_controller(method: "GET", accept: "application/json")
      controller.send(:cookies)[Authentication::Base::REFRESH_COOKIE_KEY] = "refresh-token"
      refresh_calls = 0
      controller.define_singleton_method(:refresh_access_token) do |_refresh_plain|
        refresh_calls += 1
        { user: Object.new }
      end

      controller.transparent_refresh_access_token

      assert_equal 0, refresh_calls
      assert_nil controller.request.env[Auth::IoKeys::Env::AUTH_REFRESHED_FLAG]
    end

    test "does_not_transparent_refresh_on_get_with_mixed_json_html_accept" do
      controller = build_controller(method: "GET", accept: "application/json, text/html")
      controller.send(:cookies)[Authentication::Base::REFRESH_COOKIE_KEY] = "refresh-token"
      refresh_calls = 0
      controller.define_singleton_method(:refresh_access_token) do |_refresh_plain|
        refresh_calls += 1
        { user: Object.new }
      end

      controller.transparent_refresh_access_token

      assert_equal 0, refresh_calls
      assert_nil controller.request.env[Auth::IoKeys::Env::AUTH_REFRESHED_FLAG]
    end

    test "does_not_transparent_refresh_on_get_with_malformed_htmlish_accept" do
      controller = build_controller(method: "GET", accept: "text/htmlish")
      controller.send(:cookies)[Authentication::Base::REFRESH_COOKIE_KEY] = "refresh-token"
      refresh_calls = 0
      controller.define_singleton_method(:refresh_access_token) do |_refresh_plain|
        refresh_calls += 1
        { user: Object.new }
      end

      controller.transparent_refresh_access_token

      assert_equal 0, refresh_calls
      assert_nil controller.request.env[Auth::IoKeys::Env::AUTH_REFRESHED_FLAG]
    end

    test "refreshes html get and head requests" do
      %w(GET HEAD).each do |method|
        controller = build_controller(method: method)
        resource = Object.new
        controller.send(:cookies)[Authentication::Base::REFRESH_COOKIE_KEY] = "refresh-token"
        refresh_calls = 0
        controller.define_singleton_method(:refresh_access_token) do |_refresh_plain|
          refresh_calls += 1
          { user: resource }
        end

        controller.transparent_refresh_access_token

        assert_equal 1, refresh_calls, "#{method} should transparently refresh"
        assert_equal resource, controller.instance_variable_get(:@current_resource)
        assert controller.request.env[Auth::IoKeys::Env::AUTH_REFRESHED_FLAG]
      end
    end

    private

    def build_controller(method:, accept: "text/html")
      controller = AuthenticationTransparentRefreshHarnessController.new
      request = ActionDispatch::TestRequest.create
      request.set_header("REQUEST_METHOD", method)
      request.set_header("HTTP_ACCEPT", accept)
      controller.request = request
      controller.response = ActionDispatch::TestResponse.new
      controller
    end
  end

  class CurrentResourceTest < ActionDispatch::IntegrationTest
    def test_current_resource_does_not_transparent_refresh_when_refresh_callback_skipped
      controller = build_controller(method: "POST")
      controller.send(:cookies)[Authentication::Base::REFRESH_COOKIE_KEY] = "refresh-token"
      refresh_calls = 0

      controller.define_singleton_method(:load_from_token) { nil }
      controller.define_singleton_method(:authentication_credentials_invalid?) { false }
      controller.define_singleton_method(:resource_withdrawn?) { |_resource| false }
      controller.define_singleton_method(:controller_path) { "sign/app/protected_resources" }
      controller.define_singleton_method(:refresh_access_token) do |_refresh_plain|
        refresh_calls += 1
        { user: Object.new }
      end

      assert_nil controller.current_resource
      assert_not controller.logged_in?
      assert_equal 0, refresh_calls
      assert_nil controller.request.env[Auth::IoKeys::Env::AUTH_REFRESHED_FLAG]
    end

    private

    def build_controller(method:, accept: "text/html")
      controller = AuthenticationTransparentRefreshHarnessController.new
      request = ActionDispatch::TestRequest.create
      request.set_header("REQUEST_METHOD", method)
      request.set_header("HTTP_ACCEPT", accept)
      controller.request = request
      controller.response = ActionDispatch::TestResponse.new
      controller
    end
  end
end
