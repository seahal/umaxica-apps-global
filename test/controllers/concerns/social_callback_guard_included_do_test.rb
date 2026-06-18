# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialCallbackGuardIncludedDoTest < ActiveSupport::TestCase
  class GuardHarness
    def self.before_action(*)
    end

    include SocialCallbackGuard

    attr_accessor :session_hash, :params_hash, :request_object, :redirects

    def initialize
      @session_hash = {}
      @params_hash = {}
      @request_object = ActionDispatch::TestRequest.create
      @redirects = []
    end

    def session
      session_hash
    end

    def params
      ActionController::Parameters.new(params_hash)
    end

    def request
      request_object
    end

    def redirect_to(*args, **kwargs)
      redirects << [args, kwargs]
    end

    def sign_app_sign_in_path
      "/sign/app/in"
    end
  end

  test "verify_social_callback_request! method exists (private)" do
    assert_includes SocialCallbackGuard.private_instance_methods(false), :verify_social_callback_request!
  end

  test "REQUEST_PHASE_PATH constant is defined" do
    assert_kind_of Regexp, SocialCallbackGuard::REQUEST_PHASE_PATH
  end

  test "request phase rejects missing and mismatched sources" do
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, ["id.example.test"])
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, ["https://id.example.test"])

    missing_source_env = Rack::MockRequest.env_for("/auth/apple", method: "GET")
    missing_source_env["rack.session"] = {}
    status, = SocialCallbackGuard.verify_request_phase!(missing_source_env)

    assert_equal 403, status

    mismatch_env = Rack::MockRequest.env_for(
      "/auth/apple",
      :method => "GET",
      "HTTP_ORIGIN" => "https://evil.example.test",
    )
    mismatch_env["rack.session"] = {}
    status, = SocialCallbackGuard.verify_request_phase!(mismatch_env)

    assert_equal 403, status
  ensure
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  test "request phase captures and generates state" do
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, ["id.example.test"])
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, ["https://id.example.test"])

    env = Rack::MockRequest.env_for(
      "/auth/apple?state=known-state",
      :method => "GET",
      "HTTP_ORIGIN" => "https://id.example.test",
    )
    env["rack.session"] = {}

    assert_nil SocialCallbackGuard.verify_request_phase!(env)
    assert_equal "known-state", env["rack.session"][SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
    assert_not env["rack.session"].key?(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)

    issued_count = ClientOauthCallbackState.count
    SocialCallbackGuard.capture_request_state!(env)

    assert_equal "apple", env["rack.session"][SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]
    assert_equal issued_count, ClientOauthCallbackState.count
    assert_not env["rack.session"].key?(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)

    generated_env = Rack::MockRequest.env_for(
      "/auth/apple",
      :method => "GET",
      "HTTP_ORIGIN" => "https://id.example.test",
    )
    generated_env["rack.session"] = {}

    assert_nil SocialCallbackGuard.verify_request_phase!(generated_env)
    assert_match(/state=/, generated_env["QUERY_STRING"])
    assert_predicate generated_env["rack.session"][SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY], :present?
    assert_not generated_env["rack.session"].key?(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)
  ensure
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  test "normalizes malformed origins and referer sources" do
    assert_nil SocialCallbackGuard.normalize_origin("http://[")

    origin_env = Rack::MockRequest.env_for("/", "HTTP_ORIGIN" => "http://[")
    source, normalized = SocialCallbackGuard.normalized_request_source(Rack::Request.new(origin_env))

    assert_equal :origin_parse_error, source
    assert_nil normalized

    referer_env = Rack::MockRequest.env_for("/", "HTTP_REFERER" => "http://[")
    source, normalized = SocialCallbackGuard.normalized_request_source(Rack::Request.new(referer_env))

    assert_equal :referer_parse_error, source
    assert_nil normalized

    empty_env = Rack::MockRequest.env_for("/")

    assert_equal [:missing_source, nil], SocialCallbackGuard.normalized_request_source(Rack::Request.new(empty_env))
  end

  test "callback state branches clear or record session state" do
    harness = GuardHarness.new
    harness.params_hash[:provider] = "apple"
    harness.params_hash[:state] = "callback-state"
    harness.session_hash[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY] = "callback-state"
    harness.session_hash[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY] = "apple"
    SocialAuthCallbackStateStore.issue!(state: "callback-state", provider: "apple")

    assert_equal [true, nil], harness.send(:valid_callback_state?, "apple")
    assert_predicate harness.session_hash[SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY], :present?

    harness.session_hash[SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY] = Time.current.to_i

    assert_equal [false, "state_reused"], harness.send(:valid_callback_state?, "apple")
    assert_empty harness.session_hash

    harness.params_hash[:state] = "callback-state"
    harness.session_hash[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY] = "different-state"
    SocialAuthCallbackStateStore.issue!(state: "different-state", provider: "apple")

    assert_equal [false, "state_mismatch"], harness.send(:valid_callback_state?, "apple")
    assert_empty harness.session_hash
  end

  test "callback state requires server side one time consumption" do
    harness = GuardHarness.new
    harness.params_hash[:provider] = "apple"
    harness.params_hash[:state] = "server-state"
    harness.session_hash[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY] = "server-state"
    harness.session_hash[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY] = "apple"

    assert_equal [false, "server_state_reused"], harness.send(:valid_callback_state?, "apple")
    assert_empty harness.session_hash
  end

  test "callback request rejection and default payload are recorded" do
    harness = GuardHarness.new
    harness.params_hash[:provider] = "apple"
    harness.request_object = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "DELETE",
      "HTTP_HOST" => "id.example.test",
    )

    assert_not harness.send(:evaluate_social_callback_request)
    assert_equal "bad_method", harness.request_object.env.dig("social_callback_guard.rejection", :reason)
    assert_equal "bad_state", harness.send(:default_social_callback_rejection)[:reason]

    harness.session_hash[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY] = "state"
    harness.send(:reject_social_callback!, reason: "bad_state", provider: "apple", details: {})

    assert_empty harness.session_hash
    assert_equal [["/sign/app/in"], { alert: I18n.t("sign.app.social.sessions.create.failure"), status: :forbidden }],
                 harness.redirects.last
  end

  test "callback state resolution errors clear session and raise" do
    harness = GuardHarness.new
    harness.session_hash[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY] = "state"
    harness.define_singleton_method(:load_callback_state_data) { |_| raise JSON::ParserError }

    assert_raises(JSON::ParserError) do
      harness.send(:valid_callback_state?, "apple")
    end
    assert_empty harness.session_hash
  end

  test "callback state accepts omniauth test mode mocks" do
    harness = GuardHarness.new

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:apple] = OpenStruct.new(provider: "apple")
    harness.params_hash[:provider] = "apple"

    assert harness.send(:test_mode_mock_auth_present?)
  ensure
    OmniAuth.config.mock_auth.delete(:apple) if defined?(OmniAuth)
    OmniAuth.config.test_mode = false if defined?(OmniAuth)
  end
end
