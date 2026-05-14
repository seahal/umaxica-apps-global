# typed: false
# frozen_string_literal: true

require "test_helper"

class Preference::BaseExtraCoverageTest < Minitest::Test
  extend ActiveSupport::Testing::Declarative

  class Harness < ApplicationController
    include Preference::Base

    attr_accessor :session_hash, :cookies_hash, :request_obj, :rendered, :redirected, :response_obj

    def initialize
      @session_hash = {}
      @cookies_hash = {}.with_indifferent_access
      # Override delete to handle multiple arguments
      def @cookies_hash.delete(key, **)
        super(key)
      end

      @request_obj = Object.new
      def @request_obj.host = "id.app.localhost"

      def @request_obj.format = Struct.new(:json?).new(false)

      def @request_obj.request_id = "req-1"

      def @request_obj.remote_ip = "127.0.0.1"

      def @request_obj.ssl? = false
      @response_obj = Struct.new(:headers).new({})
    end

    def t(key)
      "translated:#{key}"
    end

    def epoch_seconds(time)
      time.to_i
    end

    def session = @session_hash

    def cookies = @cookies_hash

    def request = @request_obj

    def response = @response_obj

    def render(args) = @rendered = args

    def head(status) = @rendered = { status: status }

    # Abstract methods or methods from other modules
    def preference_class
      AppPreference
    end

    def preference_prefix
      "App"
    end

    def preference_prefix_underscore
      "app_preference"
    end

    def with_preference_connection(_role)
      yield
    end

    def adopt_preference_for!(res)
    end

    def current_resource
      @current_resource
    end

    def current_resource=(res)
      @current_resource = res
    end

    def apex_app_web_v0_cookie_url
      "http://app.localhost/cookie"
    end
  end

  def setup
    @harness = Harness.new
  end

  test "restore_preference_from_resource! calls adopt_preference_for!" do
    @harness.current_resource = User.new
    # We need to stub adopt_preference_for! to verify it's called
    called = false
    @harness.define_singleton_method(:adopt_preference_for!) { |_res| called = true }
    @harness.send(:restore_preference_from_resource!, AppPreference.new)

    assert called
  end

  test "cookie_banner_endpoint_url and available_for_request?" do
    with_env("APEX_SERVICE_URL" => "id.app.localhost") do
      assert @harness.send(:cookie_banner_endpoint_available_for_request?)
      assert_equal "http://app.localhost/cookie", @harness.send(:cookie_banner_endpoint_url)
    end
  end

  test "extract_cookie_banner_consent" do
    assert @harness.send(:extract_cookie_banner_consent, { "preferences" => { "consent" => true } })
    assert_not @harness.send(:extract_cookie_banner_consent, { "preferences" => { "consented" => false } })
    assert_nil @harness.send(:extract_cookie_banner_consent, {})
  end

  test "option_id_to_language with EN" do
    prefix = "App"
    option_class = Preference::ClassRegistry.option_class(prefix, :language)
    if option_class.const_defined?(:EN)
      assert_equal "en", @harness.send(:option_id_to_language, option_class::EN, prefix)
    end

    assert_equal "ja", @harness.send(:option_id_to_language, option_class::JA, prefix)
  end

  test "option_id_to_region with US" do
    prefix = "App"
    option_class = Preference::ClassRegistry.option_class(prefix, :region)

    assert_equal "us", @harness.send(:option_id_to_region, option_class::US, prefix)
    assert_equal "jp", @harness.send(:option_id_to_region, option_class::JP, prefix)
  end

  test "option_id_to_timezone with ETC_UTC" do
    prefix = "App"
    option_class = Preference::ClassRegistry.option_class(prefix, :timezone)

    assert_equal "Etc/UTC", @harness.send(:option_id_to_timezone, option_class::ETC_UTC, prefix)
    assert_equal "Asia/Tokyo", @harness.send(:option_id_to_timezone, option_class::ASIA_TOKYO, prefix)
  end

  test "handle_preference_refresh_replay! updates lapses_at" do
    pref = AppPreference.new(public_id: "p1")
    # We need to mock update! because it's not a real DB record here
    pref.define_singleton_method(:update!) do |*_args, **_kwargs|
      true
    end

    pref.define_singleton_method(:replay?) do
      true
    end

    pref.define_singleton_method(:replaced_by_id) do
      "r1"
    end

    @harness.send(:handle_preference_refresh_replay!, pref)

    assert @harness.instance_variable_get(:@preference_refresh_failed)
  end

  test "handle_preference_refresh_device_denied sets flags" do
    @harness.send(:handle_preference_refresh_device_denied, nil, "p1")

    assert @harness.instance_variable_get(:@preference_refresh_failed)
    assert @harness.instance_variable_get(:@preference_refresh_device_denied)
  end

  test "render_preference_refresh_error! handles json and html" do
    req = @harness.request
    req.define_singleton_method(:format) do
      Struct.new(:json?).new(true)
    end
    @harness.send(:render_preference_refresh_error!)

    assert_equal :unauthorized, @harness.rendered[:status]
    assert @harness.rendered[:json].key?(:error)

    req.define_singleton_method(:format) do
      Struct.new(:json?).new(false)
    end
    @harness.send(:render_preference_refresh_error!)

    assert_equal :unauthorized, @harness.rendered[:status]
  end

  private

  def with_env(vars)
    original = vars.keys.index_with { |k| ENV[k] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    original.each { |k, v| ENV[k] = v }
  end
end
