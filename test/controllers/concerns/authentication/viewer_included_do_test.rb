# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationViewerIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Authentication::Viewer
  end

  test "included do includes Authentication::Base module" do
    assert_includes Harness.included_modules, Authentication::Base
  end

  test "active_viewer? method exists" do
    assert_includes Authentication::Viewer.instance_methods(false), :active_viewer?
  end

  test "authenticate! method exists" do
    assert_includes Authentication::Viewer.instance_methods(false), :authenticate!
  end

  test "transparent_refresh_access_token method exists" do
    assert_includes Authentication::Viewer.instance_methods(false), :transparent_refresh_access_token
  end

  test "resource_type method exists (private)" do
    assert_includes Authentication::Viewer.private_instance_methods(false), :resource_type
  end

  test "sign_in_url_with_return method exists (private)" do
    assert_includes Authentication::Viewer.private_instance_methods(false), :sign_in_url_with_return
  end
end
