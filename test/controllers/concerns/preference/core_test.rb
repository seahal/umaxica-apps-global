# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceCoreHarness < ApplicationController
  class << self
    def before_action(*) = nil
  end

  include Preference::Core

  attr_accessor :params_hash, :session_hash, :render_args, :written_cookies

  def initialize
    super
    @params_hash = {}
    @session_hash = {}
    @written_cookies = []
  end

  def params = ActionController::Parameters.new(params_hash)

  def session = session_hash

  def render(**kwargs) = self.render_args = kwargs

  def preference_prefix = "App"

  def preference_prefix_underscore = "app_preference"

  def preference_class = AppPreference

  def with_preference_connection(*) = yield

  def write_preference_cookie(key, value) = written_cookies << [key, value]

  def issue_access_token_from(*) = nil

  def sync_to_resource_preference! = nil
end

class Preference::CoreTest < ActiveSupport::TestCase
  FakeOption = Struct.new(:name)
  FakeAssociation = Struct.new(:option_id, :option)
  FakeCookie = Struct.new(:consented, :functional, :performant, :targetable)

  FakePreference =
    Struct.new(
      :language, :region, :timezone, :theme,
      :app_preference_language, :app_preference_region, :app_preference_timezone,
      :app_preference_theme, :app_preference_cookie,
      keyword_init: true,
    ) do
      def class = AppPreference

      def blank? = false

      def persisted? = false

      def reload = self

      def association(_)
        Struct.new(:loaded?) {
          define_method(:reload) { true }
        }.new(false)
      end
    end

  FakeAssociatedPreference =
    Struct.new(
      :app_preference_language, :app_preference_region, :app_preference_timezone,
      :app_preference_theme, :app_preference_cookie,
      keyword_init: true,
    ) do
      def class = AppPreference

      def blank? = false
    end

  setup do
    @controller = PreferenceCoreHarness.new
    @controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.localhost")
    @controller.response = ActionDispatch::TestResponse.new
  end

  test "preference response payload uses direct preference methods and defaults" do
    cookie = FakeCookie.new(true, false, true, false)
    @controller.instance_variable_set(
      :@preferences,
      FakePreference.new(language: "en", region: "us", timezone: "Etc/UTC", theme: "dr", app_preference_cookie: cookie),
    )

    payload = @controller.send(:preference_response_payload)

    assert_equal "en", payload[:lx]
    assert_equal "us", payload[:ri]
    assert_equal "Etc/UTC", payload[:tz]
    assert_equal "dr", payload[:ct]
    assert payload[:consented]
    assert payload[:performant]
    assert_not payload[:functional]
    assert_not payload[:targetable]

    @controller.instance_variable_set(:@preferences, nil)
    defaults = @controller.send(:preference_response_payload)

    assert_equal Current::Preference::DEFAULTS[:language], defaults[:lx]
    assert_not defaults[:consented]
  end

  test "resolved preference snapshot and cookie use associations" do
    preference = FakeAssociatedPreference.new(
      app_preference_language: FakeAssociation.new(nil, FakeOption.new("EN")),
      app_preference_region: FakeAssociation.new(nil, FakeOption.new("US")),
      app_preference_timezone: FakeAssociation.new(nil, FakeOption.new("Etc/UTC")),
      app_preference_theme: FakeAssociation.new(nil, FakeOption.new("dark")),
      app_preference_cookie: FakeCookie.new(false, true, false, true),
    )

    assert_equal(
      { language: "en", region: "us", timezone: "Etc/UTC", theme: "dr" },
      @controller.send(:resolved_preference_snapshot, preference),
    )
    assert_equal(
      { consented: false, functional: true, performant: false, targetable: true },
      @controller.send(:resolved_preference_cookie, preference),
    )
    assert_equal(
      { consented: false, functional: false, performant: false, targetable: false },
      @controller.send(:resolved_preference_cookie, nil),
    )
  end

  test "cookie params and update params cover nested and flat forms" do
    @controller.params_hash = { preference_cookie: { consented: "1",
                                                     functional: "1",
                                                     performant: "0",
                                                     targetable: "0", } }
    nested = @controller.send(:preference_cookie_params)

    assert_equal "1", nested[:consented]

    cookie = Struct.new(:consented?).new(false)
    update = @controller.send(:build_cookie_update_params, cookie, nested)

    assert update[:consented_at]

    cookie = Struct.new(:consented?).new(true)
    update = @controller.send(
      :build_cookie_update_params, cookie,
      ActionController::Parameters.new(consented: "0").permit(:consented),
    )

    assert_nil update[:consented_at]
  end

  test "safe return and color theme params cover fallback inputs" do
    @controller.params_hash = { return_to: "/safe", theme: "dark" }

    assert_equal "/safe", @controller.send(:safe_return_to_path)
    assert_equal "dark", @controller.send(:preference_colortheme_params)[:option_id]

    @controller.params_hash = { return_to: "//evil.example", ct: "dr" }

    assert_nil @controller.send(:safe_return_to_path)
    assert_equal "dr", @controller.send(:preference_colortheme_params)[:option_id]
  end

  test "render update response and reset state cover response helpers" do
    @controller.instance_variable_set(:@preferences, FakePreference.new(app_preference_cookie: nil))

    @controller.send(:render_preference_update_response)

    assert_equal :ok, @controller.render_args[:status]
    assert @controller.render_args[:json].key?(:preference)

    @controller.instance_variable_set(:@preference_payload, { "x" => 1 })
    @controller.instance_variable_set(:@refresh_token_value, "token")
    @controller.send(:reset_preference_state)

    assert_nil @controller.instance_variable_get(:@preferences)
    assert_nil @controller.instance_variable_get(:@preference_payload)
    assert_nil @controller.instance_variable_get(:@refresh_token_value)
  end
end
