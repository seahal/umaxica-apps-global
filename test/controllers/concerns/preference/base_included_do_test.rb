# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Preference::Base
  end

  test "show_cookie_banner? method exists" do
    assert_includes Preference::Base.instance_methods(false), :show_cookie_banner?
  end

  test "cookie_banner_endpoint_url method exists" do
    assert_includes Preference::Base.private_instance_methods(false), :cookie_banner_endpoint_url
  end

  test "set_preferences_cookie method exists (private)" do
    assert_includes Preference::Base.private_instance_methods(false), :set_preferences_cookie
  end

  test "ACCESS_TOKEN_TTL constant is defined" do
    assert_kind_of ActiveSupport::Duration, Preference::Base::ACCESS_TOKEN_TTL
  end

  test "REFRESH_TOKEN_TTL constant is defined" do
    assert_kind_of ActiveSupport::Duration, Preference::Base::REFRESH_TOKEN_TTL
  end
end
