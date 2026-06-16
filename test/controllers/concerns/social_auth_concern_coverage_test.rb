# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthConcernCoverageTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include SocialAuth

    attr_accessor :session_hash, :request_obj, :flash_hash, :redirected, :rendered,
                  :current_session_token

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

    def sign_app_settings_apple_path = "/apple"

    def sign_app_settings_path = "/config"

    def sign_app_sign_in_path = "/login"

    def sign_app_root_path = "/"
  end

  StepUpToken =
    Struct.new(
      :public_id,
      :last_step_up_at,
      :last_step_up_scope,
      :last_step_up_method,
      :last_step_up_session_public_id,
      :last_step_up_purpose,
      :last_step_up_audience,
      keyword_init: true,
    ) do
      def currently_usable? = true

      def has_attribute?(name)
        %w(
          last_step_up_method
          last_step_up_session_public_id
          last_step_up_purpose
          last_step_up_audience
        ).include?(name.to_s)
      end
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
    @harness.session_hash[SocialAuth::SOCIAL_INTENT_SESSION_KEY] = "link"
    @harness.session_hash[SocialAuth::SOCIAL_STARTED_AT_SESSION_KEY] = 10.minutes.ago.to_i

    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:validate_social_auth_state!)
    end
  end

  test "validate_user_consistency! raises when user changed" do
    @harness.session_hash[SocialAuth::SOCIAL_USER_ID_SESSION_KEY] = 1
    @harness.current_resource = Struct.new(:id).new(2)

    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:validate_user_consistency!, "link")
    end
  end

  test "require_recent_step_up! accepts current token-bound step-up" do
    @harness.current_resource = Client.new
    @harness.current_session_token = step_up_token(last_step_up_scope: SocialAuth::SOCIAL_LINK_SCOPE)

    assert_nothing_raised do
      @harness.send(:require_recent_step_up!)
    end
  end

  test "require_recent_step_up! rejects token-bound step-up with different scope" do
    @harness.current_resource = Client.new
    @harness.current_session_token = step_up_token(last_step_up_scope: "settings_email")

    assert_raises(SocialAuth::StepUpRequiredError) do
      @harness.send(:require_recent_step_up!)
    end
  end

  test "require_recent_step_up! rejects expired token-bound step-up" do
    @harness.current_resource = Client.new
    @harness.current_session_token = step_up_token(last_step_up_at: 1.hour.ago)

    assert_raises(SocialAuth::StepUpRequiredError) do
      @harness.send(:require_recent_step_up!)
    end
  end

  test "require_recent_step_up! rejects resource-level step-up without token-bound step-up" do
    @harness.current_resource = Client.new
    @harness.current_resource.last_step_up_at = Time.current
    @harness.current_session_token = nil

    assert_raises(SocialAuth::StepUpRequiredError) do
      @harness.send(:require_recent_step_up!)
    end
  end

  test "require_recent_step_up! rejects step-up from another session token" do
    @harness.current_resource = Client.new
    @harness.current_session_token = step_up_token(
      public_id: "current-session",
      last_step_up_session_public_id: "other-session",
    )

    assert_raises(SocialAuth::StepUpRequiredError) do
      @harness.send(:require_recent_step_up!)
    end
  end

  test "require_recent_step_up! rejects login success without step-up" do
    @harness.current_resource = Client.new
    @harness.current_session_token = step_up_token(last_step_up_at: nil)

    assert_raises(SocialAuth::StepUpRequiredError) do
      @harness.send(:require_recent_step_up!)
    end
  end

  test "require_recent_step_up! logs the binding breakdown on rejection" do
    @harness.current_resource = Client.new
    @harness.current_session_token = step_up_token(
      public_id: "current-session",
      last_step_up_session_public_id: "other-session",
    )

    log =
      capture_step_up_required_log do
        assert_raises(SocialAuth::StepUpRequiredError) do
          @harness.send(:require_recent_step_up!)
        end
      end

    assert_includes log, "required_scope"
    assert_includes log, "usable_token"
    assert_includes log, "session_bound"
    assert_includes log, "token_bound"
    assert_includes log, "purpose_bound"
    assert_includes log, "audience_bound"
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

    assert_match(/apple|settings/, path)
  end

  private

  def assert_response_redirected
    assert_predicate @harness.redirected, :present?
  end

  # Capture what require_recent_step_up! writes to Rails.logger so the rejection
  # breakdown (M2) can be asserted without depending on log formatting internals.
  def capture_step_up_required_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end

  def step_up_token(public_id: "current-session", last_step_up_at: Time.current,
                    last_step_up_scope: "verification", last_step_up_method: "passkey",
                    last_step_up_session_public_id: public_id, last_step_up_purpose: "step_up",
                    last_step_up_audience: nil)
    StepUpToken.new(
      public_id: public_id,
      last_step_up_at: last_step_up_at,
      last_step_up_scope: last_step_up_scope,
      last_step_up_method: last_step_up_method,
      last_step_up_session_public_id: last_step_up_session_public_id,
      last_step_up_purpose: last_step_up_purpose,
      last_step_up_audience: last_step_up_audience,
    )
  end
end
