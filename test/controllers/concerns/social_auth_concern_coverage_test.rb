# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthConcernCoverageTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include SocialAuthConcern

    attr_accessor :session_hash, :request_obj, :flash_hash, :redirected, :rendered

    def initialize
      super
      @session_hash = {}
      @flash_hash = {}
      @request_obj = Object.new
      def @request_obj.headers = {}

      def @request_obj.format = Struct.new(:json?).new(false)

      def @request_obj.path = "/auth/google"

      def @request_obj.env = {}

      def @request_obj.host = "localhost"

      def @request_obj.variant = []

      def @request_obj.negotiate_mime(*) = nil

      def @request_obj.optional_port = nil

      def @request_obj.protocol = "http://"

      def @request_obj.path_parameters = {}

      def @request_obj.formats = [Mime[:html]]
    end

    def session = @session_hash

    def flash = @flash_hash

    def request = @request_obj

    def params = {}

    def redirect_to(url, options = {})
      @redirected = [url, options]
    end

    def render(args)
      @rendered = args
    end

    def current_resource
      @current_resource
    end

    def current_resource=(res)
      @current_resource = res
    end

    def logged_in? = current_resource.present?

    def respond_to(&block)
      @json_mode = @request_obj.format.json?
      block.call(self)
    end

    def html
      yield unless @json_mode
    end

    def json
      yield if @json_mode
    end

    def sign_app_configuration_apple_path = "/apple"

    def sign_app_configuration_path = "/config"

    def new_sign_app_in_path = "/login"

    def sign_app_root_path = "/"
  end

  setup do
    @harness = Harness.new
  end

  test "prepare_social_auth_intent! raises on invalid intent" do
    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:prepare_social_auth_intent!, "invalid")
    end
  end

  test "prepare_social_auth_intent! raises if linking and not logged in" do
    @harness.current_resource = nil
    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:prepare_social_auth_intent!, "link")
    end
  end

  test "validate_social_auth_state! raises on expired TTL" do
    @harness.session_hash[SocialAuthConcern::SOCIAL_INTENT_SESSION_KEY] = "link"
    @harness.session_hash[SocialAuthConcern::SOCIAL_STARTED_AT_SESSION_KEY] = 10.minutes.ago.to_i

    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:validate_social_auth_state!)
    end
  end

  test "validate_user_consistency! raises when user changed" do
    @harness.session_hash[SocialAuthConcern::SOCIAL_USER_ID_SESSION_KEY] = 1
    @harness.current_resource = Struct.new(:id).new(2)

    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:validate_user_consistency!, "link")
    end
  end

  test "require_recent_reauth! raises if last reauth is old" do
    @harness.current_resource = User.new
    @harness.current_resource.last_reauth_at = 1.hour.ago

    assert_raises(SocialAuth::ReauthRequiredError) do
      @harness.send(:require_recent_reauth!)
    end
  end

  test "handle_social_auth_error redirects for html" do
    error = SocialAuth::BaseError.new("failed ❌", :bad_request)
    @harness.send(:handle_social_auth_error, error)

    assert_response_redirected
  end

  test "handle_social_auth_error renders json for json" do
    req = @harness.request
    req.define_singleton_method(:format) do
      Struct.new(:json?).new(true)
    end
    error = SocialAuth::BaseError.new("failed ❌", :bad_request)
    @harness.send(:handle_social_auth_error, error)

    assert_equal :bad_request, @harness.rendered[:status]
  end

  test "handle_record_not_unique redirects for html" do
    @harness.send(:handle_record_not_unique, StandardError.new("not unique"))

    assert_response_redirected
  end

  test "social_auth_failure_redirect_path_for_intent for apple" do
    path = @harness.send(:social_auth_failure_redirect_path_for_intent, intent: "link", provider: "apple")

    assert_match(/apple|configuration/, path)
  end

  private

  def assert_response_redirected
    assert_predicate @harness.redirected, :present?
  end
end
