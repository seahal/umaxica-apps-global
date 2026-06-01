# typed: false
# frozen_string_literal: true

require "test_helper"

class Preference::BaseExtraCoverageTest < ActiveSupport::TestCase
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

      def @request_obj.format = Struct.new(:json?, :ref).new(false, :html)

      def @request_obj.request_id = "req-1"

      def @request_obj.remote_ip = "127.0.0.1"

      def @request_obj.ssl? = false

      def @request_obj.request_method = "GET"

      def @request_obj.path = "/preference"
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

    def params = { action: "test" }.with_indifferent_access

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

    def acme_app_web_v0_cookie_url
      "http://app.localhost/cookie"
    end
  end

  def setup
    @harness = Harness.new
  end

  test "restore_preference_from_resource! calls adopt_preference_for!" do
    @harness.current_resource = Client.new
    # We need to stub adopt_preference_for! to verify it's called
    called = false
    @harness.define_singleton_method(:adopt_preference_for!) { |_res| called = true }
    @harness.send(:restore_preference_from_resource!, AppPreference.new)

    assert called
  end

  test "cookie_banner_endpoint_url and available_for_request?" do
    with_env("ACME_SERVICE_URL" => "id.app.localhost") do
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
    assert_equal "America/New_York",
                 @harness.send(:option_id_to_timezone, option_class::AMERICA_NEW_YORK, prefix)
  end

  test "handle_preference_refresh_replay! updates discarded_at" do
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

  test "handle_preference_refresh_replay! adopts the replacement within the grace window" do
    replacement = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now)
    parent = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discarded_at: 1.day.from_now,
      used_at: Time.current,
      replaced_by_id: replacement.id,
    )
    @harness.cookies["app_preference_refresh"] = "stale-cookie"

    result = @harness.send(:handle_preference_refresh_replay!, parent)

    assert_equal :grace, result
    assert_equal replacement.id, @harness.instance_variable_get(:@preferences).id
    assert_nil @harness.instance_variable_get(:@preference_refresh_failed)
    # Grace must not clear cookies; the winning sibling request owns the rotation.
    assert_equal "stale-cookie", @harness.cookies["app_preference_refresh"]
    assert_not replacement.reload.replay?, "replacement stays unconsumed for the sibling"
  end

  test "handle_preference_refresh_replay! treats a consumed token past the grace window as compromise" do
    replacement = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discarded_at: 1.day.from_now)
    window = SingleUseToken::PREFERENCE_REFRESH_GRACE_WINDOW
    parent = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discarded_at: 1.day.from_now,
      used_at: window.ago - 1.second,
      replaced_by_id: replacement.id,
    )

    result = @harness.send(:handle_preference_refresh_replay!, parent)

    assert_equal :compromised, result
    assert @harness.instance_variable_get(:@preference_refresh_failed)
    assert_not_equal replacement.id, @harness.instance_variable_get(:@preferences)&.id
  end

  test "handle_preference_refresh_replay! treats a missing replacement as compromise" do
    parent = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discarded_at: 1.day.from_now,
      used_at: Time.current,
    )

    result = @harness.send(:handle_preference_refresh_replay!, parent)

    assert_equal :compromised, result
    assert @harness.instance_variable_get(:@preference_refresh_failed)
  end

  test "handle_preference_refresh_binding_denied sets flags" do
    @harness.send(:handle_preference_refresh_binding_denied, nil, "p1")

    assert @harness.instance_variable_get(:@preference_refresh_failed)
    assert @harness.instance_variable_get(:@preference_refresh_binding_denied)
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
