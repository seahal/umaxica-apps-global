# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceBaseExtraCoverageTest < ActiveSupport::TestCase
  extend ActiveSupport::Testing::Declarative

  class Harness < ApplicationController
    include PreferenceBase

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

  test "preference_current_resource wraps failures in a resolution error" do
    @harness.define_singleton_method(:current_resource) do
      raise StandardError, "boom"
    end

    error =
      assert_raises(PreferenceBase::ResolutionError) do
        @harness.send(:preference_current_resource)
      end

    assert_match(/Preference current_resource resolution failed/, error.message)
    assert_instance_of StandardError, error.cause
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

  test "public_option_cookie_payload reads from hash and object sources" do
    assert_equal({}, @harness.send(:public_option_cookie_payload, nil))

    hash_source = { PreferenceIoKeys::Cookies::THEME => "dark", PreferenceIoKeys::Cookies::TIMEZONE => "Asia/Tokyo" }
    object_source = Object.new
    object_source.define_singleton_method(:theme) { "light" }
    object_source.define_singleton_method(:timezone) { "Etc/UTC" }
    object_source.define_singleton_method(:currency) { "jpy" }

    assert_equal(
      {
        PreferenceIoKeys::Cookies::THEME => "dark",
        PreferenceIoKeys::Cookies::TIMEZONE => "Asia/Tokyo",
      },
      @harness.send(:public_option_cookie_payload, hash_source),
    )
    assert_equal(
      {
        PreferenceIoKeys::Cookies::THEME => "light",
        PreferenceIoKeys::Cookies::TIMEZONE => "Etc/UTC",
        PreferenceIoKeys::Cookies::CURRENCY => "jpy",
      },
      @harness.send(:public_option_cookie_payload, object_source),
    )
  end

  test "preference_record_theme returns a short code when theme is present" do
    preference_theme = Struct.new(:option_id).new(7)
    preference = Struct.new(:app_preference_theme).new(preference_theme)
    @harness.instance_variable_set(:@preferences, preference)
    @harness.define_singleton_method(:preference_theme_association) { "app_preference_theme" }
    @harness.define_singleton_method(:option_id_to_theme) { |option_id, _prefix| option_id == 7 ? "dark" : nil }
    @harness.define_singleton_method(:theme_short_code) { |value| value == "dark" ? "dr" : nil }

    assert_equal "dr", @harness.send(:preference_record_theme)
    @harness.instance_variable_set(:@preferences, nil)
    assert_nil @harness.send(:preference_record_theme)
  end

  test "create_preference_association! uses creator method when available and falls back to association" do
    creator_attrs = nil
    creator_preference = Object.new
    creator_preference.define_singleton_method(:respond_to?) do |name, include_private = false|
      name == :create_app_preference_cookie! || super(name, include_private)
    end
    creator_preference.define_singleton_method(:create_app_preference_cookie!) do |attrs|
      creator_attrs = attrs
      :created
    end

    association_calls = []
    association_class = Class.new do
      define_singleton_method(:create!) do |attrs|
        association_calls << attrs
        :created
      end
    end
    association = Struct.new(:klass).new(association_class)
    fallback_preference = Object.new
    fallback_preference.define_singleton_method(:association) do |_name|
      association
    end

    assert_equal :created,
                 @harness.send(:create_preference_association!, creator_preference, "app_preference_cookie", { foo: 1 })
    assert_equal({ foo: 1 }, creator_attrs)

    assert_equal :created,
                 @harness.send(:create_preference_association!, fallback_preference, "app_preference_cookie", { foo: 2 })
    assert_equal([{ foo: 2, preference: fallback_preference }], association_calls)
  end

  test "preference_param_value maps known keys and falls back to the original type" do
    params_hash = { lx: "ja", ri: "jp", tz: "Asia/Tokyo", ct: "dark", custom: "value" }

    assert_equal "ja", @harness.send(:preference_param_value, params_hash, :language)
    assert_equal "jp", @harness.send(:preference_param_value, params_hash, :region)
    assert_equal "Asia/Tokyo", @harness.send(:preference_param_value, params_hash, :timezone)
    assert_equal "dark", @harness.send(:preference_param_value, params_hash, :theme)
    assert_equal "value", @harness.send(:preference_param_value, params_hash, :custom)
  end

  test "normalize_theme and theme_short_code map full and short values" do
    assert_nil @harness.send(:normalize_theme, nil)
    assert_equal "dr", @harness.send(:normalize_theme, "dark")
    assert_equal "li", @harness.send(:normalize_theme, "li")

    assert_nil @harness.send(:theme_short_code, nil)
    assert_equal "dr", @harness.send(:theme_short_code, "dark")
  end

  test "option_id_to_language with EN" do
    prefix = "App"
    option_class = PreferenceClassRegistry.option_class(prefix, :language)
    if option_class.const_defined?(:EN)
      assert_equal "en", @harness.send(:option_id_to_language, option_class::EN, prefix)
    end

    assert_equal "ja", @harness.send(:option_id_to_language, option_class::JA, prefix)
  end

  test "option_id_to_region with US" do
    prefix = "App"
    option_class = PreferenceClassRegistry.option_class(prefix, :region)

    assert_equal "us", @harness.send(:option_id_to_region, option_class::US, prefix)
    assert_equal "jp", @harness.send(:option_id_to_region, option_class::JP, prefix)
  end

  test "option_id_to_timezone with ETC_UTC" do
    prefix = "App"
    option_class = PreferenceClassRegistry.option_class(prefix, :timezone)

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
