# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceSanitizeTestController < ::ApplicationController
  include ::Preference::Base

  attr_accessor :test_params, :test_controller_path

  def initialize(*)
    super
    @test_params = {}
  end

  def controller_path
    @test_controller_path || "apex/app/preferences"
  end

  def params
    @test_params.with_indifferent_access
  end

  def test_sanitize_option_id(params_hash, option_type:)
    sanitize_option_id(params_hash.dup.with_indifferent_access, option_type: option_type)
  end

  def test_ensure_preference_reference_defaults!
    send(:ensure_preference_reference_defaults!)
  end
end

module Preference
  class BaseTest < ActiveSupport::TestCase
    test "preference cookie key constants are stable" do
      assert_equal "ct", Preference::Base::THEME_COOKIE_KEY
      assert_equal "language", Preference::Base::LANGUAGE_COOKIE_KEY
      assert_equal "tz", Preference::Base::TIMEZONE_COOKIE_KEY
    end
  end

  class SanitizeOptionIdTest < ActionDispatch::IntegrationTest
    setup do
      @controller = PreferenceSanitizeTestController.new
    end

    test "returns integer option_id as-is" do
      result = @controller.test_sanitize_option_id({ option_id: 1 }, option_type: :timezone)

      assert_equal 1, result[:option_id]
    end

    test "converts numeric string to integer" do
      result = @controller.test_sanitize_option_id({ option_id: "2" }, option_type: :timezone)

      assert_equal 2, result[:option_id]
    end

    test "resolves valid timezone constant name" do
      result = @controller.test_sanitize_option_id({ option_id: "ASIA_TOKYO" }, option_type: :timezone)

      assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO, result[:option_id]
    end

    test "resolves valid timezone with slash notation" do
      result = @controller.test_sanitize_option_id({ option_id: "Asia/Tokyo" }, option_type: :timezone)

      assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO, result[:option_id]
    end

    test "resolves valid language constant name" do
      result = @controller.test_sanitize_option_id({ option_id: "JA" }, option_type: :language)

      assert_equal AppPreferenceLanguageOption::JA, result[:option_id]
    end

    test "resolves valid region constant name" do
      result = @controller.test_sanitize_option_id({ option_id: "JP" }, option_type: :region)

      assert_equal AppPreferenceRegionOption::JP, result[:option_id]
    end

    test "resolves valid theme constant name" do
      result = @controller.test_sanitize_option_id({ option_id: "dark" }, option_type: :theme)

      assert_equal AppPreferenceThemeOption::DARK, result[:option_id]
    end

    test "ignores invalid constant name - returns unchanged" do
      result = @controller.test_sanitize_option_id({ option_id: "INVALID_CONST" }, option_type: :timezone)

      assert_equal "INVALID_CONST", result[:option_id]
    end

    test "ignores malicious input attempting to access arbitrary constant" do
      malicious_inputs = %w(
        RAILS_ENV
        SECRET_KEY_BASE
        ApplicationController
        Object
        Kernel
      )

      Prosopite.pause do
        malicious_inputs.each do |input|
          result = @controller.test_sanitize_option_id({ option_id: input }, option_type: :timezone)

          assert_equal input, result[:option_id], "Expected malicious input '#{input}' to be returned unchanged"
        end
      end
    end

    test "handles nil option_id" do
      result = @controller.test_sanitize_option_id({ option_id: nil }, option_type: :timezone)

      assert_nil result[:option_id]
    end

    test "handles empty string option_id" do
      result = @controller.test_sanitize_option_id({ option_id: "" }, option_type: :timezone)

      assert_nil result[:option_id]
    end

    test "normalizes lowercase input" do
      result = @controller.test_sanitize_option_id({ option_id: "asia_tokyo" }, option_type: :timezone)

      assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO, result[:option_id]
    end

    test "normalizes hyphenated input" do
      result = @controller.test_sanitize_option_id({ option_id: "asia-tokyo" }, option_type: :timezone)

      assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO, result[:option_id]
    end
  end

  class EnsureReferenceDefaultsTest < ActiveSupport::TestCase
    setup do
      @controller = PreferenceSanitizeTestController.new
    end

    teardown do
      ApplicationRecord.clear_fixed_id_seed_cache!
    end

    test "recreates missing app preference activity level defaults" do
      AppPreferenceChronicle.delete_all
      AppPreferenceChronicleLevel.where(id: AppPreferenceChronicleLevel::INFO).delete_all

      assert_nil AppPreferenceChronicleLevel.find_by(id: AppPreferenceChronicleLevel::INFO)

      @controller.test_ensure_preference_reference_defaults!

      assert_not_nil AppPreferenceChronicleLevel.find_by(id: AppPreferenceChronicleLevel::INFO)
    end

    test "recreates missing org preference activity level defaults on the activity writer" do
      @controller.test_controller_path = "core/org/preferences"
      OrgPreferenceChronicle.delete_all
      OrgPreferenceChronicleLevel.where(id: OrgPreferenceChronicleLevel::INFO).delete_all

      assert_nil OrgPreferenceChronicleLevel.find_by(id: OrgPreferenceChronicleLevel::INFO)

      @controller.test_ensure_preference_reference_defaults!

      assert_not_nil OrgPreferenceChronicleLevel.find_by(id: OrgPreferenceChronicleLevel::INFO)
    end

    test "recreates missing app preference parent reference defaults" do
      called = []

      AppPreferenceStatus.stub(:ensure_defaults!, -> { called << :status }) do
        AppPreferenceChronicleLevel.stub(:ensure_defaults!, -> { called << :chronicle_level }) do
          AppPreferenceChronicleEvent.stub(:ensure_defaults!, -> { called << :chronicle_event }) do
            AppPreferenceBindingMethod.stub(:ensure_defaults!, -> { called << :binding_method }) do
              AppPreferenceDbscStatus.stub(:ensure_defaults!, -> { called << :dbsc_status }) do
                @controller.test_ensure_preference_reference_defaults!
              end
            end
          end
        end
      end

      assert_equal %i(status chronicle_level chronicle_event binding_method dbsc_status), called
    end
  end

  class JwtConfigurationTest < ActiveSupport::TestCase
    test "active_kid returns value from ENV" do
      with_env("PREFERENCE_JWT_ACTIVE_KID" => "test_kid") do
        assert_equal "test_kid", Preference::JwtConfiguration.active_kid
      end
    end

    test "leeway_seconds returns value from ENV" do
      with_env("PREFERENCE_JWT_LEEWAY_SECONDS" => "45") do
        assert_equal 45, Preference::JwtConfiguration.leeway_seconds
      end
    end

    test "issuer returns value from ENV" do
      with_env("PREFERENCE_JWT_ISSUER" => "test-issuer") do
        assert_equal "test-issuer", Preference::JwtConfiguration.issuer
      end
    end

    test "audiences returns split values from ENV" do
      with_env("PREFERENCE_JWT_AUDIENCES" => "aud1, aud2 , aud3") do
        assert_equal %w(aud1 aud2 aud3), Preference::JwtConfiguration.audiences
      end
    end

    test "audience_for filters to matching TLD only" do
      with_env("PREFERENCE_JWT_AUDIENCES" => "umaxica.app,umaxica.com,localhost") do
        result = Preference::JwtConfiguration.audience_for("id.umaxica.app")

        assert_includes result, "umaxica.app"
        assert_includes result, "localhost", "localhost is included in non-production"
        assert_not_includes result, "umaxica.com"
      end
    end

    test "audience_for returns only matching TLD for com host" do
      with_env("PREFERENCE_JWT_AUDIENCES" => "umaxica.app,umaxica.com,localhost") do
        result = Preference::JwtConfiguration.audience_for("wwww.umaxica.com")

        assert_includes result, "umaxica.com"
        assert_includes result, "localhost"
        assert_not_includes result, "umaxica.app"
      end
    end

    test "audience_for includes localhost for localhost host" do
      with_env("PREFERENCE_JWT_AUDIENCES" => "umaxica.app,umaxica.com,localhost") do
        result = Preference::JwtConfiguration.audience_for("id.app.localhost")

        assert_includes result, "localhost"
        assert_not_includes result, "umaxica.app"
        assert_not_includes result, "umaxica.com"
      end
    end

    test "audience_for returns all audiences when host is blank" do
      with_env("PREFERENCE_JWT_AUDIENCES" => "umaxica.app,umaxica.com") do
        result = Preference::JwtConfiguration.audience_for("")

        assert_equal %w(umaxica.app umaxica.com), result
      end
    end

    test "audience_for falls back to the current host when no TLD matches" do
      with_env("PREFERENCE_JWT_AUDIENCES" => "umaxica.app,umaxica.com") do
        result = Preference::JwtConfiguration.audience_for("example.org")

        assert_equal %w(example.org), result
      end
    end

    test "audience_for keeps org preference tokens host-scoped when org audience is not configured" do
      with_env("PREFERENCE_JWT_AUDIENCES" => "umaxica.app,umaxica.com,localhost") do
        result = Preference::JwtConfiguration.audience_for("id.umaxica.org")

        assert_equal %w(id.umaxica.org), result
      end
    end

    test "host_scope_for uses matching configured audience for sibling hosts" do
      with_env("PREFERENCE_JWT_AUDIENCES" => "umaxica.app,umaxica.com") do
        assert_equal "umaxica.app", Preference::JwtConfiguration.host_scope_for("id.umaxica.app")
        assert_equal "umaxica.com", Preference::JwtConfiguration.host_scope_for("www.umaxica.com")
      end
    end

    test "host_scope_for falls back to host when no configured audience matches" do
      with_env("PREFERENCE_JWT_AUDIENCES" => "umaxica.app,umaxica.com") do
        assert_equal "id.umaxica.org", Preference::JwtConfiguration.host_scope_for("id.umaxica.org")
      end
    end

    test "parse_header decodes token header" do
      token = JWT.encode({ foo: "bar" }, nil, "none", { kid: "test_kid" })
      header = Preference::JwtConfiguration.parse_header(token)

      assert_equal "test_kid", header["kid"]
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

  class TokenTest < ActiveSupport::TestCase
    setup do
      @preferences = { "theme" => "dark" }.freeze
      @host = "app.localhost"
      @type = "user"
      @public_id = "test_id"
      @jti = "test_jti"

      # Generate a test EC key
      @key = OpenSSL::PKey::EC.generate("secp384r1")
      @der = Base64.encode64(@key.to_der)
      @pub_der = Base64.encode64(@key.public_to_der)
    end

    test "encode and decode a valid token" do
      Preference::JwtConfiguration.stub(:private_key_for_active, @key) do
        Preference::JwtConfiguration.stub(:public_key_for, @key) do
          Preference::JwtConfiguration.stub(:active_kid, "test_kid") do
            token = Preference::Token.encode(
              @preferences,
              host: @host,
              preference_type: @type,
              public_id: @public_id,
              jti: @jti,
            )

            assert_not_nil token

            decoded = Preference::Token.decode(token, host: @host)

            assert_not_nil decoded
            assert_equal @preferences, decoded["preferences"]
            assert_equal Preference::JwtConfiguration.host_scope_for(@host), decoded["host"]
            assert_equal @type, decoded["preference_type"]
            assert_equal @public_id, decoded["public_id"]
            assert_equal @jti, decoded["jti"]
          end
        end
      end
    end

    test "decode returns nil for invalid host" do
      Preference::JwtConfiguration.stub(:private_key_for_active, @key) do
        Preference::JwtConfiguration.stub(:public_key_for, @key) do
          Preference::JwtConfiguration.stub(:active_kid, "test_kid") do
            token = Preference::Token.encode(
              @preferences,
              host: @host,
              preference_type: @type,
              public_id: @public_id,
              jti: @jti,
            )

            assert_nil Preference::Token.decode(token, host: "wrong.host")
          end
        end
      end
    end

    test "extract_preferences returns preferences from payload" do
      payload = { "preferences" => { "theme" => "light" } }

      assert_equal({ "theme" => "light" }, Preference::Token.extract_preferences(payload))
      assert_equal({}, Preference::Token.extract_preferences(nil))
    end
  end

  class PreferenceBaseMethodsTest < ActiveSupport::TestCase
    FakePreferenceState =
      Struct.new(
        :binding_method, :dbsc_status, :dbsc_session_id, :expires_at,
        :device_id, :device_id_digest, :status_id, :discarded_at, :replaced_by_id, :public_id,
        keyword_init: true,
      ) do
        def binding_method_dbsc? = binding_method == :dbsc

        def binding_method_legacy? = binding_method == :legacy

        def dbsc_status_pending? = dbsc_status == :pending

        def dbsc_status_active? = dbsc_status == :active

        def dbsc_status_failed? = dbsc_status == :failed

        def dbsc_status_revoke? = dbsc_status == :revoke

        def replay? = false

        def accessible?
          discarded_at.nil? ||
            (discarded_at.respond_to?(:infinite?) && discarded_at.infinite?) ||
            discarded_at > Time.current
        end

        def revoked? = discarded_at.present? && discarded_at <= Time.current
      end

    setup do
      Actor.reset
      @controller = PreferenceSanitizeTestController.new
      @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.localhost")
      @controller.response = ActionDispatch::TestResponse.new
    end

    teardown do
      Actor.reset
    end

    test "resolve_option_id_from_param returns default for blank value" do
      assert_equal 99, @controller.send(:resolve_option_id_from_param, nil, :timezone, 99, "prefix")
      assert_equal 99, @controller.send(:resolve_option_id_from_param, "", :timezone, 99, "prefix")
    end

    test "resolve preference transport delegates to legacy preference cookie pipeline" do
      delegated = false
      @controller.define_singleton_method(:set_preferences_cookie) { delegated = true }

      @controller.send(:resolve_preference_transport)

      assert delegated
    end

    test "preference edit entry refresh copies resource preference before issuing token" do
      resource = Object.new
      resource_preference = Object.new
      shared_preference = Object.new
      calls = []

      @controller.instance_variable_set(:@preferences, shared_preference)
      @controller.define_singleton_method(:current_resource) { resource }
      @controller.define_singleton_method(:resolved_resource_preference) { |candidate|
        (candidate == resource) ? resource_preference : nil
      }
      @controller.define_singleton_method(:copy_preference_values!) do |source, target, prefix|
        calls << [:copy, source, target, prefix]
      end
      @controller.define_singleton_method(:preference_prefix) { "App" }
      @controller.define_singleton_method(:reload_preference_for_token!) do |preference|
        calls << [:reload, preference]
      end
      @controller.define_singleton_method(:issue_access_token_from) do |preference|
        calls << [:issue, preference]
      end

      @controller.send(:refresh_preference_token_from_db_for_edit_entry!)

      assert_equal [
        [:copy, resource_preference, shared_preference, "App"],
        [:reload, shared_preference],
        [:issue, shared_preference],
      ], calls
    end

    test "preference edit entry refresh is a no-op without a logged-in resource preference" do
      calls = []

      @controller.instance_variable_set(:@preferences, Object.new)
      @controller.define_singleton_method(:current_resource) { nil }
      @controller.define_singleton_method(:copy_preference_values!) do |_source, _target, _prefix|
        calls << :copy
      end

      @controller.send(:refresh_preference_token_from_db_for_edit_entry!)

      assert_empty calls
    end

    test "resolve_option_id_from_param returns integer for valid input" do
      assert_equal AppPreferenceTimezoneOption::ASIA_TOKYO,
                   @controller.send(:resolve_option_id_from_param, "Asia/Tokyo", :timezone, 99, "prefix")
    end

    test "preference child records are created with the parent association" do
      preference = Object.new
      option_ids = Preference::ClassRegistry::CHILD_RECORD_TYPES.index_with.with_index { |_, index| index + 1 }
      created_records = []
      record_class =
        Class.new do
          define_singleton_method(:create!) { |attributes| created_records << attributes }
        end
      Preference::ClassRegistry::CHILD_RECORD_TYPES.each do |type|
        preference.define_singleton_method(:"create_app_preference_#{type}!") do |attributes|
          created_records << attributes
        end
      end

      Preference::ClassRegistry.stub(:record_class, ->(_prefix, _type) { record_class }) do
        @controller.send(:create_preference_option_records, "App", preference, option_ids)
      end

      assert_equal Preference::ClassRegistry::CHILD_RECORD_TYPES.size, created_records.size
      assert_equal option_ids.values, created_records.pluck(:option_id)
      assert created_records.none? { |attributes| attributes.key?(:preference_id) }
      assert created_records.none? { |attributes| attributes.key?(:preference) }
    end

    test "preference child records are created on their model writing connection" do
      preference = Object.new
      option_ids = Preference::ClassRegistry::CHILD_RECORD_TYPES.index_with.with_index { |_, index| index + 1 }
      roles = []
      created_records = []
      Preference::ClassRegistry::CHILD_RECORD_TYPES.each do |type|
        preference.define_singleton_method(:"create_app_preference_#{type}!") do |attributes|
          created_records << attributes
        end
      end

      connection_owner =
        Class.new(ApplicationRecord) do
          self.abstract_class = true
        end
      connection_owner.define_singleton_method(:connected_to) do |role:, &block|
        roles << role
        block.call
      end

      record_class = Class.new(connection_owner)
      record_class.define_singleton_method(:create!) { |attributes| created_records << attributes }

      Preference::ClassRegistry.stub(:record_class, ->(_prefix, _type) { record_class }) do
        @controller.send(:create_preference_option_records, "App", preference, option_ids)
      end

      assert_equal Array.new(Preference::ClassRegistry::CHILD_RECORD_TYPES.size, :writing), roles
      assert_equal Preference::ClassRegistry::CHILD_RECORD_TYPES.size, created_records.size
    end

    test "preference cookie is created with the parent association" do
      preference = Object.new
      created_attributes = nil
      preference.define_singleton_method(:create_app_preference_cookie!) do |attributes|
        created_attributes = attributes
      end
      cookie_class =
        Class.new do
          define_singleton_method(:create!) { |attributes| created_attributes = attributes }
        end

      Preference::ClassRegistry.stub(:cookie_class, ->(_prefix) { cookie_class }) do
        @controller.send(:create_preference_cookie, "App", preference)
      end

      assert_not created_attributes[:functional]
      assert_not created_attributes.key?(:preference_id)
      assert_not created_attributes.key?(:preference)
    end

    test "normalized_locale returns sym for valid locale" do
      I18n.stub(:available_locales, [:en, :ja]) do
        assert_equal :en, @controller.send(:normalized_locale, "en")
        assert_equal :ja, @controller.send(:normalized_locale, "JA")
        assert_nil @controller.send(:normalized_locale, "invalid")
        assert_nil @controller.send(:normalized_locale, "")
      end
    end

    test "locale_from_region returns mapped locale" do
      assert_equal "ja", @controller.send(:locale_from_region, "jp")
      assert_equal "en", @controller.send(:locale_from_region, "us")
      assert_nil @controller.send(:locale_from_region, "unknown")
    end

    test "available_locale_strings returns unique lowercased strings" do
      I18n.stub(:available_locales, %i(en JA en)) do
        # Clear memoized value
        @controller.instance_variable_set(:@available_locale_strings, nil)

        assert_equal %w(en ja), @controller.send(:available_locale_strings)
      end
    end

    test "host_matches? handles direct and subdomain matches" do
      # Since host_matches? is in Preference::Token (which is a class)
      # Wait, I see host_matches? in Preference::Token class << self
      assert Preference::Token.send(:host_matches?, "example.com", "example.com")
      assert Preference::Token.send(:host_matches?, "example.com", "sub.example.com")
      assert_not Preference::Token.send(:host_matches?, "example.com", "other.com")
      assert_not Preference::Token.send(:host_matches?, nil, "example.com")
    end

    test "audience_matches? handles multiple audiences" do
      assert Preference::Token.send(:audience_matches?, ["a.com", "b.com"], "a.com")
      assert Preference::Token.send(:audience_matches?, ["a.com", "b.com"], "sub.b.com")
      assert_not Preference::Token.send(:audience_matches?, ["a.com", "b.com"], "c.com")
    end

    test "cookie banner endpoint returns nil when host is not expected" do
      @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "wrong.localhost")

      assert_nil @controller.send(:cookie_banner_endpoint_url)
      assert_not @controller.send(:cookie_banner_endpoint_available_for_request?)
    end

    test "extract_cookie_banner_consent handles consent aliases" do
      assert_nil @controller.send(:extract_cookie_banner_consent, nil)
      assert_nil @controller.send(:extract_cookie_banner_consent, "bad")
      assert_nil @controller.send(:extract_cookie_banner_consent, { "preferences" => "bad" })
      assert @controller.send(:extract_cookie_banner_consent, { "preferences" => { "consent" => true } })
      assert_not @controller.send(:extract_cookie_banner_consent, { "preferences" => { "consented" => false } })
    end

    test "preference dbsc helpers name binding status payload and expiry" do
      dbsc = FakePreferenceState.new(
        binding_method: :dbsc,
        dbsc_status: :active,
        dbsc_session_id: "session-1",
        discarded_at: 20.minutes.from_now,
      )
      legacy = FakePreferenceState.new(binding_method: :legacy, dbsc_status: :pending)
      nothing = FakePreferenceState.new(binding_method: :nothing, dbsc_status: :nothing)

      @controller.define_singleton_method(:preference_dbsc_path) { "/dbsc" }

      assert_equal "dbsc", @controller.send(:dbsc_binding_method_name, dbsc)
      assert_equal "legacy", @controller.send(:dbsc_binding_method_name, legacy)
      assert_equal "nothing", @controller.send(:dbsc_binding_method_name, nothing)
      assert_equal "pending", @controller.send(:dbsc_status_name, legacy)
      assert_equal "active", @controller.send(:dbsc_status_name, dbsc)
      assert_equal "nothing", @controller.send(:dbsc_status_name, nothing)
      assert_equal(
        {
          binding_method: "dbsc",
          status: "active",
          session_id: "session-1",
          registration_url: "/dbsc",
          verification_url: "/dbsc",
        },
        @controller.send(:preference_dbsc_payload_for, dbsc),
      )
      assert_nil @controller.send(:preference_dbsc_payload_for, nil)
      assert_in_delta 10.minutes.from_now.to_i, @controller.send(:preference_dbsc_cookie_expires_at, dbsc).to_i, 1
      assert_nil @controller.send(:preference_dbsc_cookie_expires_at, legacy)
    end

    test "preference refresh binding validates device cookie and dbsc cookie" do
      @controller.define_singleton_method(:digest_device_id) { |value| "digest:#{value}" }
      @controller.send(:cookies)[@controller.send(:preference_device_id_cookie_name)] =
        "device-1"
      legacy = FakePreferenceState.new(binding_method: :legacy, device_id_digest: "digest:device-1")

      assert @controller.send(:preference_refresh_binding_allowed?, legacy)

      legacy.device_id_digest = "other"

      assert_not @controller.send(:preference_refresh_binding_allowed?, legacy)
      assert_equal "mismatch", @controller.instance_variable_get(:@preference_refresh_device_reason)

      dbsc = FakePreferenceState.new(binding_method: :dbsc, dbsc_status: :pending, dbsc_session_id: "session-1")

      assert_not @controller.send(:preference_refresh_binding_allowed?, dbsc)
      assert_equal "dbsc_not_active", @controller.instance_variable_get(:@preference_refresh_device_reason)

      dbsc.dbsc_status = :active

      assert_not @controller.send(:preference_refresh_binding_allowed?, dbsc)
      assert_equal "missing_bound_cookie", @controller.instance_variable_get(:@preference_refresh_device_reason)

      @controller.send(:cookies)[@controller.send(:preference_dbsc_cookie_name)] = "wrong"

      assert_not @controller.send(:preference_refresh_binding_allowed?, dbsc)
      assert_equal "session_id_mismatch", @controller.instance_variable_get(:@preference_refresh_device_reason)

      @controller.send(:cookies)[@controller.send(:preference_dbsc_cookie_name)] = "session-1"

      assert @controller.send(:preference_refresh_binding_allowed?, dbsc)
    end

    test "refresh token data and preference status helpers handle edge cases" do
      assert_equal [nil, nil], @controller.send(:refresh_token_data, nil)

      @controller.define_singleton_method(:parse_refresh_token) { |_| ["public-id", "verifier"] }
      @controller.define_singleton_method(:digest_refresh_token) { |value| "digest:#{value}" }

      assert_equal ["public-id", "digest:verifier"], @controller.send(:refresh_token_data, "token")

      status_class = Class.new
      status_class.const_set(:DELETED, 99)
      @controller.define_singleton_method(:preference_status_class) { status_class }
      valid = FakePreferenceState.new(status_id: 1, discarded_at: 5.minutes.from_now)
      deleted = FakePreferenceState.new(status_id: 99, discarded_at: 5.minutes.from_now)
      expired = FakePreferenceState.new(status_id: 1, discarded_at: 1.minute.ago)
      revoked = FakePreferenceState.new(status_id: 1, discarded_at: Time.current)

      assert @controller.send(:valid_refresh_preference?, valid)
      assert_not @controller.send(:valid_refresh_preference?, nil)
      assert_not @controller.send(:valid_refresh_preference?, deleted)
      assert_not @controller.send(:valid_refresh_preference?, expired)
      assert_not @controller.send(:valid_refresh_preference?, revoked)
    end

    test "preference payload and cookie helpers expose stored values" do
      @controller.instance_variable_set(
        :@preference_payload,
        { "preferences" => { "ct" => "dr" }, "public_id" => "pref-public", "jti" => "jti-1" },
      )

      assert_equal({ "ct" => "dr" }, @controller.send(:preference_payload_preferences))
      assert_equal "dr", @controller.send(:preference_payload_value, :ct)
      assert_equal "pref-public", @controller.send(:preference_payload_public_id)
      assert_equal "jti-1", @controller.send(:preference_payload_jti)

      expires_at = 1.hour.from_now
      @controller.send(:set_refresh_token_cookie, "refresh-token", expires_at)
      @controller.send(:set_preference_dbsc_cookie!, "dbsc-token", expires_at: expires_at)
      @controller.send(:set_preference_device_id_cookie!, "device-1", expires_at: expires_at)

      assert_equal "refresh-token", @controller.send(:cookies)[@controller.send(:refresh_token_cookie_name)]
      assert_equal "dbsc-token", @controller.send(:cookies)[@controller.send(:preference_dbsc_cookie_name)]
      assert_equal "device-1", @controller.send(:read_preference_device_id_cookie)

      deletion_options = @controller.send(:preference_cookie_deletion_options)

      assert_not deletion_options.key?(:expires)
      assert_equal :lax, deletion_options[:same_site]
    end

    test "load access token payload falls back when referenced preference record is missing" do
      payload = {
        "preferences" => { "ct" => "dr" },
        "public_id" => "missing-public",
      }
      relation = Struct.new(:record) do
        define_method(:find_by) do |*|
          record
        end
      end.new(nil)

      @controller.send(:cookies)[@controller.send(:access_token_cookie_name)] = "access-token"

      [AppPreference, ComPreference, OrgPreference].each do |klass|
        @controller.instance_variable_set(:@preferences, nil)
        @controller.instance_variable_set(:@preference_payload, nil)

        Preference::Token.stub(:decode, payload) do
          Preference::Token.stub(:extract_preference_type, klass.name) do
            Preference::Token.stub(:extract_public_id, "missing-public") do
              klass.stub(:includes, relation) do
                @controller.define_singleton_method(:preference_class) { klass }

                assert_not @controller.send(:load_access_token_payload)
                assert_nil @controller.instance_variable_get(:@preferences)
                assert_nil @controller.instance_variable_get(:@preference_payload)
                assert_nil @controller.send(:cookies)[@controller.send(:access_token_cookie_name)]
              end
            end
          end
        end
      end
    end

    test "load access token payload reads preference record through writing connection" do
      preference = app_preferences(:one)
      preference.update!(jti: "current-jti")
      payload = {
        "preferences" => { "ct" => "dr" },
        "public_id" => "existing-public",
        "jti" => "current-jti",
      }
      relation = Struct.new(:record) do
        define_method(:find_by) do |*|
          record
        end
      end.new(preference)

      roles = []
      @controller.send(:cookies)[@controller.send(:access_token_cookie_name)] = "access-token"

      Preference::Token.stub(:decode, payload) do
        Preference::Token.stub(:extract_preference_type, AppPreference.name) do
          Preference::Token.stub(:extract_public_id, "existing-public") do
            AppPreference.stub(:includes, relation) do
              @controller.define_singleton_method(:with_preference_connection) do |role, &block|
                roles << role
                block.call
              end

              assert @controller.send(:load_access_token_payload)
              assert_equal preference, @controller.instance_variable_get(:@preferences)
              assert_equal [:writing], roles
            end
          end
        end
      end
    end

    test "load access token payload rejects stale preference jti" do
      preference = app_preferences(:one)
      preference.update!(jti: "current-jti")
      payload = {
        "preferences" => { "ct" => "dr" },
        "public_id" => preference.public_id,
        "jti" => "stale-jti",
      }
      relation = Struct.new(:record) do
        define_method(:find_by) do |*|
          record
        end
      end.new(preference)

      @controller.send(:cookies)[@controller.send(:access_token_cookie_name)] = "access-token"

      Preference::Token.stub(:decode, payload) do
        Preference::Token.stub(:extract_preference_type, AppPreference.name) do
          Preference::Token.stub(:extract_public_id, preference.public_id) do
            Preference::Token.stub(:extract_jti, "stale-jti") do
              AppPreference.stub(:includes, relation) do
                @controller.define_singleton_method(:preference_class) { AppPreference }

                assert_not @controller.send(:load_access_token_payload)
                assert_nil @controller.instance_variable_get(:@preferences)
                assert_nil @controller.instance_variable_get(:@preference_payload)
                assert_nil @controller.send(:cookies)[@controller.send(:access_token_cookie_name)]
              end
            end
          end
        end
      end
    end

    test "load access token payload rejects missing jti when preference row has current jti" do
      preference = app_preferences(:one)
      preference.update!(jti: "current-jti")
      payload = {
        "preferences" => { "ct" => "dr" },
        "public_id" => preference.public_id,
      }
      relation = Struct.new(:record) do
        define_method(:find_by) do |*|
          record
        end
      end.new(preference)

      @controller.send(:cookies)[@controller.send(:access_token_cookie_name)] = "access-token"

      Preference::Token.stub(:decode, payload) do
        Preference::Token.stub(:extract_preference_type, AppPreference.name) do
          Preference::Token.stub(:extract_public_id, preference.public_id) do
            AppPreference.stub(:includes, relation) do
              @controller.define_singleton_method(:preference_class) { AppPreference }

              assert_not @controller.send(:load_access_token_payload)
              assert_nil @controller.instance_variable_get(:@preferences)
              assert_nil @controller.instance_variable_get(:@preference_payload)
              assert_nil @controller.send(:cookies)[@controller.send(:access_token_cookie_name)]
            end
          end
        end
      end
    end

    test "load access token payload allows legacy preference rows without jti" do
      preference = app_preferences(:one)
      preference.update!(jti: nil)
      payload = {
        "preferences" => { "ct" => "dr" },
        "public_id" => preference.public_id,
        "jti" => "legacy-token-jti",
      }
      relation = Struct.new(:record) do
        define_method(:find_by) do |*|
          record
        end
      end.new(preference)

      @controller.send(:cookies)[@controller.send(:access_token_cookie_name)] = "access-token"

      Preference::Token.stub(:decode, payload) do
        Preference::Token.stub(:extract_preference_type, AppPreference.name) do
          Preference::Token.stub(:extract_public_id, preference.public_id) do
            AppPreference.stub(:includes, relation) do
              @controller.define_singleton_method(:preference_class) { AppPreference }

              assert @controller.send(:load_access_token_payload)
              assert_equal preference, @controller.instance_variable_get(:@preferences)
            end
          end
        end
      end
    end

    test "banner theme class and audit helper edge branches" do
      assert_not @controller.show_cookie_banner?
      @controller.define_singleton_method(:current_resource) { Object.new }
      @controller.define_singleton_method(:adopt_preference_for!) { |_| raise RuntimeError, "boom" }

      assert_nil @controller.send(:restore_preference_from_resource!, Object.new)

      @controller.instance_variable_set(:@preference_class, AppPreference)

      assert_equal AppPreferenceStatus, @controller.send(:preference_status_class)
      assert_equal "app_preference_colortheme", @controller.send(:preference_colortheme_association)

      @controller.instance_variable_set(:@preferences, Object.new)
      association = Struct.new(:option_id).new(AppPreferenceThemeOption::DARK)
      @controller.instance_variable_get(:@preferences).define_singleton_method(:app_preference_colortheme) {
        association
      }
      @controller.define_singleton_method(:preference_payload_value) { |_| nil }
      @controller.send(:set_color_theme)

      assert_equal "dr", @controller.instance_variable_get(:@color_theme)
    end

    test "set color theme uses actor preference before jwt payload and cookie" do
      Actor.preference = Actor::Preference.new(theme: "dr")
      @controller.send(:cookies)[Preference::Base::THEME_COOKIE_KEY] = "li"
      @controller.define_singleton_method(:preference_payload_value) { |_| "sy" }

      @controller.send(:set_color_theme)

      assert_equal "dr", @controller.instance_variable_get(:@color_theme)
    end

    test "set color theme keeps explicit request parameter before actor preference" do
      Actor.preference = Actor::Preference.new(theme: "dr")
      @controller.test_params = { Preference::IoKeys::Params::CT => "li" }

      @controller.send(:set_color_theme)

      assert_equal "li", @controller.instance_variable_get(:@color_theme)
    end

    test "cookie banner endpoint resolves helper on expected host" do
      old = ENV["APEX_SERVICE_URL"]
      ENV["APEX_SERVICE_URL"] = "id.app.localhost"
      @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.localhost")
      @controller.define_singleton_method(:apex_app_web_v0_cookie_url) { "https://id.app.localhost/web/v0/cookie" }

      assert @controller.send(:cookie_banner_endpoint_available_for_request?)
      assert_equal "https://id.app.localhost/web/v0/cookie", @controller.send(:cookie_banner_endpoint_url)
    ensure
      ENV["APEX_SERVICE_URL"] = old
    end

    test "preference class mapping and option fallback helpers cover unknown branches" do
      unknown_class = Class.new
      unknown_class.define_singleton_method(:name) { "UnknownPreference" }
      @controller.instance_variable_set(:@preference_class, unknown_class)

      assert_raises(ArgumentError) { @controller.send(:preference_binding_method_class) }
      assert_raises(ArgumentError) { @controller.send(:preference_dbsc_status_class) }

      assert_equal "zz", @controller.send(:option_id_to_language, "ZZ", "App")
      assert_equal "xx", @controller.send(:option_id_to_region, "XX", "App")
      assert_equal "Mars/Base", @controller.send(:option_id_to_timezone, "Mars/Base", "App")
      assert_equal "contrast", @controller.send(:option_id_to_colortheme, "contrast", "App")
    end

    test "refresh failure handlers and render error branches set state" do
      @controller.define_singleton_method(:preference_class) { AppPreference }
      @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.localhost")
      @controller.request.request_id = "request-1"

      preference = FakePreferenceState.new(public_id: "pref-public")
      @controller.send(:handle_preference_refresh_failed, preference, nil)

      assert @controller.send(:preference_refresh_failed?)

      @controller.send(:clear_preference_refresh_failure!)
      @controller.instance_variable_set(:@preference_refresh_device_reason, "missing")
      @controller.send(:handle_preference_refresh_device_denied, preference, nil)

      assert @controller.send(:preference_refresh_failed?)
      assert @controller.instance_variable_get(:@preference_refresh_device_denied)

      rendered = []
      headed = []
      @controller.define_singleton_method(:render) { |**kwargs| rendered << kwargs }
      @controller.define_singleton_method(:head) { |status| headed << status }

      @controller.request.set_header("HTTP_ACCEPT", "application/json")
      @controller.send(:render_preference_refresh_error!)

      assert_equal :unauthorized, rendered.last[:status]

      @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.localhost")
      @controller.request.request_id = "request-1"
      @controller.request.set_header("HTTP_ACCEPT", "text/html")
      @controller.send(:render_preference_refresh_error!)

      assert_equal :unauthorized, headed.last
    end

    test "refresh token lifetime covers replay failed and rotated branches" do
      rotated_class =
        Class.new do
          class << self
            define_method(:rotated=) do |val|
              @rotated = val; end

            define_method(:rotated) do
              @rotated; end

            define_method(:name) do
              "AppPreference"
            end

            define_method(:rotate!) do |**|
              rotated
            end
          end
        end

      preference = FakePreferenceState.new(binding_method: :legacy, public_id: "pref-public")
      preference.define_singleton_method(:class) { rotated_class }
      replay = FakePreferenceState.new(binding_method: :legacy, public_id: "replay-public")
      replay.define_singleton_method(:replay?) { true }

      @controller.instance_variable_set(:@refresh_token_value, "old-refresh")
      @controller.instance_variable_set(:@refresh_presented_digest, "digest")
      @controller.define_singleton_method(:find_preference_by_presented_token) { replay }
      @controller.define_singleton_method(:handle_preference_refresh_replay!) { |pref| @handled_replay = pref }

      rotated_class.rotated = nil
      @controller.send(:refresh_refresh_token_lifetime, preference)

      assert_equal replay, @controller.instance_variable_get(:@handled_replay)

      rotated = FakePreferenceState.new(
        binding_method: :dbsc,
        dbsc_session_id: "dbsc-session",
        discarded_at: 2.hours.from_now,
        public_id: "rotated-public",
      )
      rotated.define_singleton_method(:class) { rotated_class }
      rotated.define_singleton_method(:issued_refresh_token) { "new-refresh" }
      rotated.define_singleton_method(:device_id) { "device-1" }
      rotated.define_singleton_method(:binding_method_dbsc?) { true }
      rotated_class.rotated = rotated

      calls = []
      @controller.define_singleton_method(:create_audit_log) { |**kwargs| calls << [:audit, kwargs] }
      @controller.define_singleton_method(:set_refresh_token_cookie) { |token, discarded_at|
        calls << [:refresh_cookie, token, discarded_at]
      }
      @controller.define_singleton_method(:set_preference_dbsc_cookie!) { |token, expires_at:|
        calls << [:dbsc_cookie, token, expires_at]
      }
      @controller.define_singleton_method(:set_preference_device_id_cookie!) { |device_id, expires_at:|
        calls << [:device_cookie, device_id, expires_at]
      }
      @controller.define_singleton_method(:issue_preference_dbsc_registration_header_for) { |pref|
        calls << [:dbsc_header, pref]
      }
      @controller.define_singleton_method(:preference_dbsc_cookie_expires_at) { |_| 10.minutes.from_now }

      @controller.send(:refresh_refresh_token_lifetime, preference)

      assert_equal rotated, @controller.instance_variable_get(:@preferences)
      assert_equal "new-refresh", @controller.instance_variable_get(:@refresh_token_value)
      assert_includes calls.map(&:first), :audit
      assert_includes calls.map(&:first), :refresh_cookie
      assert_includes calls.map(&:first), :dbsc_cookie
      assert_includes calls.map(&:first), :device_cookie
    end

    test "load preference record from refresh token covers valid invalid and create branches" do
      preference = FakePreferenceState.new(binding_method: :legacy, status_id: 1, discarded_at: 2.hours.from_now)
      @controller.define_singleton_method(:refresh_token_value) { "refresh-token" }
      @controller.define_singleton_method(:refresh_token_data) { |_| ["public-id", "digest"] }
      @controller.define_singleton_method(:find_refresh_preference) { |*, **| preference }
      @controller.define_singleton_method(:valid_refresh_preference?) { |_| true }

      assert_equal [preference, false], @controller.send(:load_preference_record_from_refresh_token!)

      @controller.instance_variable_set(:@preferences, nil)
      @controller.define_singleton_method(:valid_refresh_preference?) { |_| false }
      @controller.define_singleton_method(:handle_preference_refresh_failed) { |*| @preference_refresh_failed = true }

      assert_equal [nil, false], @controller.send(:load_preference_record_from_refresh_token!)

      @controller.instance_variable_set(:@preferences, nil)
      @controller.define_singleton_method(:refresh_token_value) { nil }
      @controller.define_singleton_method(:find_refresh_preference) { |*, **| nil }
      created = FakePreferenceState.new(binding_method: :legacy)
      @controller.define_singleton_method(:create_new_preference_record!) { created }

      assert_equal [created, true],
                   @controller.send(:load_preference_record_from_refresh_token!, create_if_missing: true)
    end
  end

  class BuildPreferencesPayloadTest < ActiveSupport::TestCase
    FakeCookie = Struct.new(:consented, :functional, :performant, :targetable, keyword_init: true)
    FakePreference =
      Struct.new(
        :app_preference_language, :app_preference_region, :app_preference_timezone,
        :app_preference_theme, :app_preference_currency, :app_preference_date_format,
        :app_preference_time_format, :app_preference_motion, :app_preference_density,
        :app_preference_items_per_page, :app_preference_cookie, keyword_init: true,
      ) do
        def class
          AppPreference
        end
      end

    setup do
      @controller = PreferenceSanitizeTestController.new
    end

    test "build_preferences_payload includes consent categories from cookie record" do
      cookie = FakeCookie.new(consented: true, functional: true, performant: false, targetable: false)
      preference = FakePreference.new(app_preference_cookie: cookie)

      payload = @controller.send(:build_preferences_payload, preference)

      assert payload["consented"]
      assert payload["functional"]
      assert_not payload["performant"]
      assert_not payload["targetable"]
      assert_equal Actor::Preference::SCHEMA_VERSION, payload["ver"]
      assert_equal "ja", payload["lx"]
      assert_equal "jp", payload["ri"]
      assert_equal "Asia/Tokyo", payload["tz"]
      assert_equal "sy", payload["ct"]
    end

    test "build_preferences_payload defaults consent to false when cookie is nil" do
      preference = FakePreference.new(app_preference_cookie: nil)

      payload = @controller.send(:build_preferences_payload, preference)

      assert_not payload["consented"]
      assert_not payload["functional"]
      assert_not payload["performant"]
      assert_not payload["targetable"]
    end

    test "build_preferences_payload does not include legacy consent key" do
      preference = FakePreference.new(app_preference_cookie: nil)

      payload = @controller.send(:build_preferences_payload, preference)

      assert_not payload.key?("consent"), "legacy 'consent' key should no longer be present"
    end
  end
end
