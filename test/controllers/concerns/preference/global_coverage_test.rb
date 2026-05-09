# typed: false
# frozen_string_literal: true

require "test_helper"

class Preference::GlobalCoverageTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Preference::Global

    attr_accessor :params_hash, :session_hash, :request_obj, :redirected, :cookies_hash

    def initialize
      super
      @params_hash = {}
      @session_hash = {}
      @cookies_hash = {}.with_indifferent_access
      @request_obj = Object.new
      def @request_obj.host = "localhost"

      def @request_obj.base_url = "http://localhost"

      def @request_obj.path = "/test"

      def @request_obj.query_parameters = {}

      def @request_obj.get? = true

      def @request_obj.head? = false

      def @request_obj.protocol = "http://"

      def @request_obj.port = 80
    end

    def params = ActionController::Parameters.new(@params_hash)

    def session = @session_hash

    def request = @request_obj

    def cookies = @cookies_hash

    def redirect_to(url, options = {})
      @redirected = [url, options]
    end

    def redirected_to
      @redirected&.first
    end

    def performed?
      false
    end

    def preference_payload_preferences = { "ri" => "us", "lx" => "en", "tz" => "UTC", "ct" => "dr" }

    def preference_prefix(_pref = nil) = "App"

    def preference_prefix_underscore = "app_preference"

    def theme_short_code(_val) = "dr"

    def option_id_to_region(*) = "jp"

    def option_id_to_language(*) = "ja"

    def option_id_to_timezone(*) = "Asia/Tokyo"

    def write_preference_cookie(*) = nil

    def set_locale_from_params = nil

    def set_timezone_from_session = nil

    def preference_payload_value(_key) = "UTC"
  end

  setup do
    @harness = Harness.new
  end

  test "resolve_param_context returns effective_context" do
    assert @harness.resolve_param_context.key?(:ri)
  end

  test "ensure_required_ri! redirects when ri mismatch" do
    @harness.params_hash = { ri: "jp" }
    # Mock effective_context to return us
    @harness.define_singleton_method(:effective_context) do
      { ri: "us" }
    end
    @harness.ensure_required_ri!

    assert_equal "http://localhost/test?ri=us", @harness.redirected_to
  end

  test "requested_context filters params" do
    @harness.params_hash = { ri: "jp", lx: "ja", other: "value" }
    context = @harness.requested_context

    assert_equal "jp", context[:ri]
    assert_equal "ja", context[:lx]
    assert_not context.key?(:other)
  end

  test "cookie_context merges payload and record" do
    @harness.instance_variable_set(:@preferences, AppPreference.new)
    context = @harness.cookie_context

    assert_equal "jp", context[:ri]
    assert_equal "ja", context[:lx]
  end

  test "default_url_options includes requested context" do
    @harness.params_hash = { ri: "us" }
    opts = @harness.default_url_options

    assert_equal "us", opts[:ri]
  end

  test "set_timezone sets session and cookies" do
    @harness.send(:set_timezone)

    assert_equal "UTC", @harness.session[:timezone]
  end

  test "set_locale calls write_preference_cookie" do
    # We need to verify write_preference_cookie is called
    called = false
    @harness.define_singleton_method(:write_preference_cookie) { |*| called = true }
    @harness.send(:set_locale)

    assert called
  end

  test "set_region redirects if ri is missing" do
    @harness.params_hash = {}
    # We need to mock url_for
    @harness.define_singleton_method(:url_for) do |*|
      "http://localhost/test?ri=jp"
    end
    @harness.send(:set_region)

    assert_equal "http://localhost/test?ri=jp", @harness.redirected_to
  end
end
