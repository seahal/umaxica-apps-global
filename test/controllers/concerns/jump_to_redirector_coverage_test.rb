# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class JumpToRedirectorCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < ApplicationController
    include JumpToRedirector

    attr_accessor :rendered, :redirected, :request_obj, :params_obj

    def initialize
      super
      @request_obj = Struct.new(:session_options).new({})
      @response_obj = Struct.new(:headers) do
        def set_header(name, value)
          headers[name] = value
        end
      end.new({})
    end

    def request
      @request_obj
    end

    def response
      @response_obj
    end

    def params
      @params_obj || ActionController::Parameters.new({})
    end

    def params=(value)
      @params_obj = value
    end

    def render(**kwargs)
      @rendered = kwargs
    end

    def redirect_to_external_jump_url(url, allowed_urls:)
      @redirected = [url, allowed_urls]
    end

    def signed_target_internal_path(path)
      path
    end

    def signed_target_clean_string(value)
      value
    end

    def signed_target_claims(**)
      { "flow" => "jump", "surface" => "app", "session_nonce" => "jump" }
    end

    def issue_signed_target_token(**kwargs)
      kwargs[:payload].to_json
    end

    def verified_signed_target_payload(token, **)
      JSON.parse(token)
    end
  end

  setup do
    @harness = Harness.new
  end

  test "render_not_found and disable_cookie_session cover low-level branches" do
    @harness.send(:disable_cookie_session)

    assert @harness.request.session_options[:skip]

    @harness.send(:render_not_found)

    assert_equal :not_found, @harness.rendered[:status]
    assert_equal "text/plain", @harness.rendered[:content_type]
  end

  test "allowed host normalization handles schemes, ports, blanks and invalid entries" do
    with_env("JUMP_ALLOWED_HOSTS" => "https://example.test, http://example.test:80, , bad://uri") do
      hosts = @harness.send(:allowed_hosts)

      assert_equal 2, hosts.count("example.test")
      assert_includes hosts, "uri"
      assert @harness.send(:allowed_jump_host?, URI.parse("https://example.test/path"))
      assert_not @harness.send(:allowed_jump_host?, URI.parse("https://blocked.test/path"))
      assert_nil @harness.send(:normalize_allowed_host, " ")
    end
  end

  test "issue and verify jump target token use matching path and host" do
    with_env("JUMP_ALLOWED_HOSTS" => "example.test") do
      token = @harness.send(:issue_jump_target_token, url: "https://example.test/path?a=1", path: "/path?a=1")

      assert_predicate token, :present?
      destination = @harness.send(:verified_jump_target, token)

      assert_equal(
        {
          "url" => "https://example.test/path?a=1",
          "path" => "/path?a=1",
        }, destination,
      )
    end
  end

  test "show renders not found when target token is missing or invalid" do
    @harness.params = ActionController::Parameters.new({})
    @harness.show

    assert_equal :not_found, @harness.rendered[:status]
  end

  test "show redirects when the signed target is valid" do
    with_env("JUMP_ALLOWED_HOSTS" => "example.test") do
      @harness.params = ActionController::Parameters.new(
        jt: @harness.send(:issue_jump_target_token, url: "https://example.test/path", path: "/path"),
      )

      @harness.show

      assert_equal ["https://example.test/path", ["https://example.test/path"]], @harness.redirected
    end
  end

  test "safe_jump_destination rejects invalid destinations and jump_target_surface tracks controller namespace" do
    with_env("JUMP_ALLOWED_HOSTS" => "example.test") do
      assert_nil @harness.send(:safe_jump_destination, "mailto:test@example.test")
      assert_nil @harness.send(:safe_jump_destination, "https://user@example.test/path")
      assert_nil @harness.send(:safe_jump_destination, "https://example.test/#frag")
      assert_nil @harness.send(:safe_jump_destination, "https://blocked.test/path")
      assert_equal(
        { "url" => "https://example.test/path", "path" => "/path" },
        @harness.send(:safe_jump_destination, "https://example.test/path"),
      )
    end

    app_harness =
      Class.new(Harness) do
        module_eval do
          def self.name = "Sign::App::JumpHarness"
        end
      end.new
    com_harness =
      Class.new(Harness) do
        module_eval do
          def self.name = "Sign::Com::JumpHarness"
        end
      end.new
    org_harness =
      Class.new(Harness) do
        module_eval do
          def self.name = "Sign::Org::JumpHarness"
        end
      end.new

    assert_equal "app", app_harness.send(:jump_target_surface)
    assert_equal "com", com_harness.send(:jump_target_surface)
    assert_equal "org", org_harness.send(:jump_target_surface)
  end

  private

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
