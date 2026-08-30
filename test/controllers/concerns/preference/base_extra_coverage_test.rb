# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

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

    def base_app_web_v0_cookie_url
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
    with_env("PRIVATE_BASE_SERVICE_URL" => "id.app.localhost") do
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
    @harness.define_singleton_method(:option_id_to_theme) { |option_id, _prefix| (option_id == 7) ? "dark" : nil }
    @harness.define_singleton_method(:theme_short_code) { |value| (value == "dark") ? "dr" : nil }

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
    association_class =
      Class.new do
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
                 @harness.send(
                   :create_preference_association!, fallback_preference, "app_preference_cookie",
                   { foo: 2 },
                 )
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

  test "clear_legacy_preference_auth_cookies deletes old apex scoped names" do
    deleted = []
    cookies = @harness.cookies
    cookies.define_singleton_method(:delete) do |key, **options|
      deleted << [key, options]
      super(key)
    end

    JitSessionCookieConfig.stub(:force_secure?, true) do
      @harness.send(:clear_legacy_preference_auth_cookies!)
    end

    domain_deletions = deleted.select { |(_key, options)| options[:domain] == ".app.localhost" }

    assert_includes domain_deletions.map(&:first), "__Secure-preference_refresh"
    assert_includes domain_deletions.map(&:first), "__Secure-app_preference_refresh"
    assert_not_includes domain_deletions.map(&:first), "__Host-preference_refresh"
    assert_not_includes domain_deletions.map(&:first), "__Host-app_preference_refresh"
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

  test "cookie_banner_endpoint_url skips a helper name the harness does not implement" do
    @harness.define_singleton_method(:respond_to?) do |name, include_private = false|
      next false if name == :base_app_web_v0_cookie_url

      super(name, include_private)
    end
    @harness.define_singleton_method(:base_com_web_v0_cookie_url) { "http://com.localhost/cookie" }

    with_env("PRIVATE_BASE_SERVICE_URL" => "id.app.localhost") do
      assert_equal "http://com.localhost/cookie", @harness.send(:cookie_banner_endpoint_url)
    end
  end

  test "cookie_banner_endpoint_url tries the next helper after a UrlGenerationError" do
    @harness.define_singleton_method(:base_app_web_v0_cookie_url) do
      raise ActionController::UrlGenerationError, "no route matches"
    end
    @harness.define_singleton_method(:base_com_web_v0_cookie_url) { "http://com.localhost/cookie" }

    with_env("PRIVATE_BASE_SERVICE_URL" => "id.app.localhost") do
      assert_equal "http://com.localhost/cookie", @harness.send(:cookie_banner_endpoint_url)
    end
  end

  test "cookie_banner_endpoint_available_for_request? resolves the org private host" do
    @harness.request.define_singleton_method(:host) { "id.org.localhost" }

    with_env("PRIVATE_BASE_STAFF_URL" => "id.org.localhost") do
      assert @harness.send(:cookie_banner_endpoint_available_for_request?)
    end
  end

  test "cookie_banner_endpoint_available_for_request? returns false for a surface without a mapped private host" do
    @harness.request.define_singleton_method(:host) { "id.dev.localhost" }

    assert_not @harness.send(:cookie_banner_endpoint_available_for_request?)
  end

  test "extract_cookie_banner_consent returns nil when neither consent key is present" do
    assert_nil @harness.send(:extract_cookie_banner_consent, { "preferences" => {} })
  end

  test "preference_record_theme returns nil when the theme association is missing" do
    preference = Struct.new(:app_preference_theme).new(nil)
    @harness.instance_variable_set(:@preferences, preference)
    @harness.define_singleton_method(:preference_theme_association) { "app_preference_theme" }

    assert_nil @harness.send(:preference_record_theme)
  end

  test "preference_option_classes maps every child record type to its option class" do
    classes = @harness.send(:preference_option_classes, "App")

    assert_equal AppPreferenceLanguageOption, classes[:language]
    assert_equal AppPreferenceThemeOption, classes[:theme]
    assert_equal PreferenceClassRegistry::CHILD_RECORD_TYPES, classes.keys
  end

  test "set_timezone_from_session sets Time.zone only when a session timezone is present" do
    Time.use_zone(Time.zone) do
      @harness.session[:timezone] = "Asia/Tokyo"

      @harness.send(:set_timezone_from_session)

      assert_equal "Asia/Tokyo", Time.zone.name
    end
  end

  test "set_timezone_from_session leaves Time.zone untouched when the session has no timezone" do
    Time.use_zone("Etc/UTC") do
      @harness.session[:timezone] = nil

      @harness.send(:set_timezone_from_session)

      assert_equal "Etc/UTC", Time.zone.name
    end
  end

  test "default_audit_ip returns the IPv4 loopback address" do
    assert_equal "127.0.0.1", @harness.send(:default_audit_ip)
  end

  test "canonical_theme_option_id returns nil for a blank value" do
    assert_nil @harness.send(:canonical_theme_option_id, nil)
    assert_nil @harness.send(:canonical_theme_option_id, "")
  end

  test "preference_binding_method_class maps ClientToken and OperatorToken to their binding method classes" do
    @harness.define_singleton_method(:preference_class) { ClientToken }

    assert_equal ClientTokenBindingMethod, @harness.send(:preference_binding_method_class)

    @harness.define_singleton_method(:preference_class) { OperatorToken }

    assert_equal OperatorTokenBindingMethod, @harness.send(:preference_binding_method_class)
  end

  test "preference_dbsc_status_class maps ClientToken and OperatorToken to their dbsc status classes" do
    @harness.define_singleton_method(:preference_class) { ClientToken }

    assert_equal ClientTokenDbscStatus, @harness.send(:preference_dbsc_status_class)

    @harness.define_singleton_method(:preference_class) { OperatorToken }

    assert_equal OperatorTokenDbscStatus, @harness.send(:preference_dbsc_status_class)
  end

  test "update_preference_child_with_audit is a no-op when the child or attributes are blank" do
    assert_nil @harness.send(:update_preference_child_with_audit, nil, { foo: 1 }, :some_event)
    assert_nil @harness.send(:update_preference_child_with_audit, Object.new, {}, :some_event)
  end

  test "preference_payload_option_ids skips associations the preference does not implement" do
    preference = Object.new
    preference.define_singleton_method(:app_preference_theme) { Struct.new(:option_id).new(3) }

    option_ids = @harness.send(:preference_payload_option_ids, preference, "app_preference")

    assert_equal 3, option_ids[:theme]
    assert_nil option_ids[:language]
  end

  test "preference_cookie_consent_state defaults to false when the preference lacks the cookie association" do
    result = @harness.send(:preference_cookie_consent_state, Object.new, "app_preference")

    assert_equal({ consented: false, functional: false, performant: false, targetable: false }, result)
  end

  test "preference_cookie_consent_state rescues a malformed cookie record and defaults to false" do
    cookie = Object.new
    cookie.define_singleton_method(:consented) { raise NoMethodError, "boom" }
    preference = Object.new
    preference.define_singleton_method(:app_preference_cookie) { cookie }

    result = @harness.send(:preference_cookie_consent_state, preference, "app_preference")

    assert_equal({ consented: false, functional: false, performant: false, targetable: false }, result)
  end

  test "dbsc_status_name reports failed and revoke states" do
    failed = Struct.new(:dbsc_status) do
      def dbsc_status_pending? = false

      def dbsc_status_active? = false

      def dbsc_status_failed? = true

      def dbsc_status_revoke? = false
    end.new(:failed)
    revoke = Struct.new(:dbsc_status) do
      def dbsc_status_pending? = false

      def dbsc_status_active? = false

      def dbsc_status_failed? = false

      def dbsc_status_revoke? = true
    end.new(:revoke)

    assert_equal "failed", @harness.send(:dbsc_status_name, failed)
    assert_equal "revoke", @harness.send(:dbsc_status_name, revoke)
  end

  test "preference_dbsc_cookie_expires_at also considers revoked_at when present" do
    preference = Struct.new(:binding_method, :expires_at, :revoked_at) do
      def binding_method_dbsc? = binding_method == :dbsc
    end.new(:dbsc, 2.hours.from_now, 5.minutes.from_now)

    result = @harness.send(:preference_dbsc_cookie_expires_at, preference)

    assert_in_delta 5.minutes.from_now.to_i, result.to_i, 1
  end

  test "issue_preference_dbsc_registration_header_for is a no-op for a nil or already dbsc-bound preference" do
    assert_nil @harness.send(:issue_preference_dbsc_registration_header_for, nil)

    dbsc_preference = Struct.new(:binding_method) do
      def binding_method_dbsc? = true
    end.new(:dbsc)

    assert_nil @harness.send(:issue_preference_dbsc_registration_header_for, dbsc_preference)
    assert_empty @harness.response.headers
  end

  test "preference_dbsc_path canonicalizes the App, Org, and Com registration routes" do
    @harness.define_singleton_method(:preference_class) { AppPreference }
    @harness.define_singleton_method(:acme_app_edge_v0_dbsc_path) { "/app/dbsc?ri=jp" }

    assert_equal "/app/dbsc", @harness.send(:preference_dbsc_path)

    @harness.define_singleton_method(:preference_class) { OrgPreference }
    @harness.define_singleton_method(:acme_org_edge_v0_dbsc_path) { "/org/dbsc?tz=Asia" }

    assert_equal "/org/dbsc", @harness.send(:preference_dbsc_path)

    @harness.define_singleton_method(:preference_class) { ComPreference }
    @harness.define_singleton_method(:acme_com_edge_v0_dbsc_path) { "/com/dbsc?ct=dr" }

    assert_equal "/com/dbsc", @harness.send(:preference_dbsc_path)
  end

  test "preference_dbsc_path returns nil for a preference class without a mapped registration route" do
    @harness.define_singleton_method(:preference_class) { ClientToken }

    assert_nil @harness.send(:preference_dbsc_path)
  end

  test "preference_cookie_surface returns nil for a preference class without a mapped surface" do
    @harness.define_singleton_method(:preference_class) { ClientToken }

    assert_nil @harness.send(:preference_cookie_surface)
  end

  test "preference_refresh_log_context omits format when the request format is unavailable" do
    @harness.request.define_singleton_method(:format) { nil }

    context = @harness.send(:preference_refresh_log_context, nil, "refresh-public")

    assert_not context.key?(:format)
  end

  test "ensure_model_defaults! is a no-op for a blank class or one without ensure_defaults!" do
    assert_nil @harness.send(:ensure_model_defaults!, nil)

    klass_without_hook = Class.new

    assert_nil @harness.send(:ensure_model_defaults!, klass_without_hook)
  end

  test "ensure_model_defaults! calls ensure_defaults! directly when the class owns no writing connection" do
    klass =
      Class.new do
        class << self
          attr_reader :ensure_defaults_called

          def ensure_defaults!
            @ensure_defaults_called = true
          end
        end
      end

    @harness.send(:ensure_model_defaults!, klass)

    assert klass.ensure_defaults_called
  end

  test "load_or_create_preference_child creates the missing child and returns it" do
    created = Object.new
    calls = []
    preference = Object.new
    preference.define_singleton_method(:app_preference_widget) do
      calls << :read
      nil
    end
    preference.define_singleton_method(:create_app_preference_widget!) do |attrs|
      calls << [:create, attrs]
      created
    end
    @harness.instance_variable_set(:@preferences, preference)

    result = @harness.send(:load_or_create_preference_child, :widget, { option_id: 1 })

    assert_equal created, result
    assert_includes calls, [:create, { option_id: 1 }]
  end

  test "load_or_create_preference_child reloads and re-reads on a unique constraint race" do
    read_calls = 0
    preference = Object.new
    preference.define_singleton_method(:app_preference_widget) do
      read_calls += 1
      (read_calls == 1) ? nil : :reloaded_child
    end
    preference.define_singleton_method(:create_app_preference_widget!) do |_attrs|
      raise ActiveRecord::RecordNotUnique, "duplicate key"
    end
    preference.define_singleton_method(:reload) { self }
    @harness.instance_variable_set(:@preferences, preference)

    result = @harness.send(:load_or_create_preference_child, :widget)

    assert_equal :reloaded_child, result
    assert_equal 2, read_calls
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

# DAMP local route helper aliases for former shared test support.
class PreferenceBaseExtraCoverageTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end
