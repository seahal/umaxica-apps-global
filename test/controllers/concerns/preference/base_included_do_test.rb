# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include PreferenceBase
  end

  test "show_cookie_banner? method exists" do
    assert_includes PreferenceBase.instance_methods(false), :show_cookie_banner?
  end

  test "cookie_banner_endpoint_url method exists" do
    assert_includes PreferenceBase.private_instance_methods(false), :cookie_banner_endpoint_url
  end

  test "set_preferences_cookie method exists (private)" do
    assert_includes Harness.private_instance_methods, :set_preferences_cookie
    assert_includes PreferenceTransport.private_instance_methods(false), :set_preferences_cookie
  end

  test "ACCESS_TOKEN_TTL constant is defined" do
    assert_kind_of ActiveSupport::Duration, PreferenceBase::ACCESS_TOKEN_TTL
  end

  test "REFRESH_TOKEN_TTL constant is defined" do
    assert_kind_of ActiveSupport::Duration, PreferenceBase::REFRESH_TOKEN_TTL
  end

  test "including base does not register preference callbacks implicitly" do
    callbacks = Harness._process_action_callbacks.map(&:filter)

    assert_not_includes callbacks, :set_preferences_cookie
  end
end
