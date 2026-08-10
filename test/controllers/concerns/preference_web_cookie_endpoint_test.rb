# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceWebCookieEndpointTest < ActiveSupport::TestCase
  class Harness
    include PreferenceWebCookieEndpoint

    attr_accessor :params_value, :payload_value

    def params = params_value || {}

    def decoded_preference_payload = payload_value

    def invoke(name, ...) = send(name, ...)
  end

  test "cookie state falls back when decoding raises" do
    harness = Harness.new
    harness.define_singleton_method(:decoded_preference_payload) { raise JWT::DecodeError, "invalid" }

    assert_equal(
      { consented: false, functional: false, performant: false, targetable: false },
      harness.invoke(:cookie_consent_state),
    )
  end

  test "buffer synchronization is non-fatal" do
    harness = Harness.new
    harness.define_singleton_method(:set_consented_buffer_cookie!) { raise ArgumentError, "invalid buffer" }

    assert harness.invoke(:sync_consented_buffer_cookie_safely!)
  end

  test "override state is observable" do
    harness = Harness.new

    assert_not harness.invoke(:cookie_consent_state_overridden?)
    harness.instance_variable_set(:@cookie_consent_state_override, { consented: true })

    assert harness.invoke(:cookie_consent_state_overridden?)
    assert_equal({ consented: true }, harness.invoke(:cookie_consent_state))
  end

  test "hash cookie parameters are filtered and cast" do
    harness = Harness.new
    harness.params_value = {
      cookie: { consented: "1", functional: "false", performant: "TRUE", targetable: 0, ignored: true },
    }

    assert_equal(
      { consented: true, functional: false, performant: true, targetable: false },
      harness.invoke(:requested_cookie_consent_attrs).with_indifferent_access.symbolize_keys,
    )
    assert harness.invoke(:cast_cookie_boolean, "T")
    assert_not harness.invoke(:cast_cookie_boolean, "F")
    assert_raises(ActionController::BadRequest) { harness.invoke(:cast_cookie_boolean, "sometimes") }
  end

  test "refresh expiry returns nil when preference lookup raises" do
    harness = Harness.new
    harness.payload_value = { "public_id" => "preference-id" }
    harness.define_singleton_method(:find_preference_by_public_id) { |_| raise ActiveRecord::StatementInvalid, "offline" }

    assert_nil harness.invoke(:refresh_token_expires_at)
  end

  test "preference cookie loader returns existing cookie or creates defaults" do
    existing = Object.new
    preference_class = Class.new
    preference_class.define_singleton_method(:name) { "ExamplePreference" }
    preference = preference_class.new
    preference.define_singleton_method(:example_preference_cookie) { existing }
    harness = Harness.new

    assert_same existing, harness.invoke(:load_or_create_preference_cookie!, preference)

    preference.define_singleton_method(:example_preference_cookie) { nil }
    preference.define_singleton_method(:create_example_preference_cookie!) { |attributes| attributes }
    created = harness.invoke(:load_or_create_preference_cookie!, preference)

    assert_equal(
      { targetable: false, performant: false, functional: false, consented: false },
      created,
    )
  end
end
