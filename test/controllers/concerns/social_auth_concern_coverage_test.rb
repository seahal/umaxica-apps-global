# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Reopens the existing Sign::Com / Sign::Org namespaces so a test harness class
# name matches the `self.class.name` regexes in
# SocialAuth#social_auth_observability_surface (there is no other way to
# exercise that classification without a real controller under those
# namespaces).
module Sign
  module Com
    class SocialAuthConcernSurfaceHarness
      include SocialAuth
    end
  end

  module Org
    class SocialAuthConcernSurfaceHarness
      include SocialAuth
    end
  end
end

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

      def @request_obj.path = "/social/google"

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

    def auth_app_settings_apple_path = "/apple"

    def auth_app_settings_path = "/config"

    def auth_app_sign_in_path = "/login"

    def auth_app_root_path = "/"
  end

  # Overrides #resource_class so social_auth_user's respond_to?(:resource_class)
  # branch (as opposed to its Client fallback) is exercised.
  class ResourceClassHarness < Harness
    def resource_class = Operator
  end

  # A plain object (not an ActionController::Base subclass) so it does not
  # automatically pick up Rails' generated named-route helper methods --
  # unlike Harness above, this lets respond_to?(:auth_app_settings_apple_path)
  # etc. be false, exercising the concern's Rails.application.routes.url_helpers
  # fallbacks instead of the local override.
  class RouteFallbackHarness
    include SocialAuth

    attr_accessor :session_hash, :request_obj

    def initialize
      @session_hash = {}
      @request_obj = Object.new
      @request_obj.define_singleton_method(:path) { "/social/apple" }
    end

    def session = @session_hash

    def request = @request_obj

    def params = {}
  end

  # A plain object so it does not automatically pick up ActionPolicy's
  # allowed_to? controller helper, exercising social_auth_link_allowed?'s
  # policy_class fallback instead.
  class LinkAuthorizationHarness
    include SocialAuth
  end

  # Minimal object graph for social_auth_current_session_token, which only
  # needs respond_to? checks and (optionally) a public-id lookup -- no
  # controller session/request plumbing.
  class BareSessionTokenHarness
    include SocialAuth
  end

  class SessionPublicIdHarness
    include SocialAuth

    attr_accessor :current_session_public_id

    def token_class = Client
  end

  # Minimal object graph for social_auth_authorization_resource's fallback
  # chain (current_resource -> current_client -> current_operator ->
  # current_visitor).
  class AuthorizationResourceHarness
    include SocialAuth

    attr_accessor :current_resource, :current_client, :current_operator, :current_visitor
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
    logged =
      capture_error_context_log do
        @harness.send(:handle_social_auth_error, error)
      end

    assert_response_redirected
    assert_includes logged, "social_auth.error_context"
    assert_includes logged, "intent"
    assert_includes logged, "request_path"
  end

  test "handle_social_auth_error emits specialized reason events" do
    error = SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent")
    logged =
      capture_error_context_log do
        @harness.send(:handle_social_auth_error, error)
      end

    assert_includes logged, "social_auth.intent.invalid"
  end

  test "handle_social_auth_error renders json for json" do
    req = @harness.request
    req.define_singleton_method(:format) do
      Struct.new(:json?).new(true)
    end
    error = SocialAuth::BaseError.new("failed ❌", :bad_request)
    capture_error_context_log do
      @harness.send(:handle_social_auth_error, error)
    end

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

  test "require_recent_step_up! is a no-op without a current resource" do
    @harness.current_resource = nil

    assert_nothing_raised do
      @harness.send(:require_recent_step_up!)
    end
  end

  test "social_auth_current_session_token returns nil when no session lookup is available" do
    harness = BareSessionTokenHarness.new

    assert_nil harness.send(:social_auth_current_session_token)
  end

  test "social_auth_current_session_token returns nil when the session public id is blank" do
    harness = SessionPublicIdHarness.new
    harness.current_session_public_id = ""

    assert_nil harness.send(:social_auth_current_session_token)
  end

  test "social_auth_current_session_token looks up the token by session public id" do
    harness = SessionPublicIdHarness.new
    harness.current_session_public_id = clients(:one).public_id

    assert_equal clients(:one), harness.send(:social_auth_current_session_token)
  end

  test "process_social_auth_callback raises a provider error for a failed callback result" do
    failure = ExternalAuthentication::Failure.new(
      code: :verification_failed,
      provider: "google",
      retryable: false,
      safe_reason: :assertion_invalid,
    )
    callback_result = ExternalAuthentication::CallbackResult.failed(failure: failure)

    assert_raises(SocialAuth::ProviderError) do
      @harness.send(:process_social_auth_callback, callback_result)
    end
  end

  test "social_auth_identity_for_callback returns nil for a non-principal object" do
    assert_nil @harness.send(:social_auth_identity_for_callback, "not-a-principal")
  end

  test "omniauth_authorize_path uses the provider name as-is for unrecognized providers" do
    assert_equal "/social/line", @harness.send(:omniauth_authorize_path, "line")
  end

  test "social_auth_user returns nil when not linking and no current resource" do
    @harness.current_resource = nil

    assert_nil @harness.send(:social_auth_user)
  end

  test "social_auth_user returns nil when linking without a stored user id" do
    @harness.current_resource = nil
    @harness.session_hash[SocialAuth::SOCIAL_INTENT_SESSION_KEY] = "link"

    assert_nil @harness.send(:social_auth_user)
  end

  test "social_auth_user falls back to Client when resource_class is undefined" do
    @harness.current_resource = nil
    @harness.session_hash[SocialAuth::SOCIAL_INTENT_SESSION_KEY] = "link"
    @harness.session_hash[SocialAuth::SOCIAL_USER_ID_SESSION_KEY] = clients(:one).id

    assert_equal clients(:one), @harness.send(:social_auth_user)
  end

  test "social_auth_user resolves via a custom resource_class when defined" do
    harness = ResourceClassHarness.new
    harness.current_resource = nil
    harness.session_hash[SocialAuth::SOCIAL_INTENT_SESSION_KEY] = "link"
    harness.session_hash[SocialAuth::SOCIAL_USER_ID_SESSION_KEY] = operators(:one).id

    assert_equal operators(:one), harness.send(:social_auth_user)
  end

  test "authorize_social_auth_link! raises when resource is nil" do
    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:authorize_social_auth_link!, nil)
    end
  end

  test "authorize_social_auth_link! allows a client resource that owns itself" do
    harness = LinkAuthorizationHarness.new
    resource = Client.new

    assert_nothing_raised do
      harness.send(:authorize_social_auth_link!, resource)
    end
  end

  test "authorize_social_auth_link! allows an operator resource that owns itself" do
    harness = LinkAuthorizationHarness.new
    resource = Operator.new

    assert_nothing_raised do
      harness.send(:authorize_social_auth_link!, resource)
    end
  end

  test "authorize_social_auth_link! raises when resource type has no policy" do
    harness = LinkAuthorizationHarness.new
    resource = Object.new

    assert_raises(SocialAuth::UnauthorizedError) do
      harness.send(:authorize_social_auth_link!, resource)
    end
  end

  test "store_social_ceremony_grant! rejects an operation the concern does not recognize" do
    token = ceremony_grant_token(operation: "account_selection")

    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:store_social_ceremony_grant!, token)
    end
  end

  test "store_social_ceremony_grant! rejects an undecodable token" do
    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:store_social_ceremony_grant!, "not-a-real-token")
    end
  end

  test "store_social_ceremony_grant! rejects a link grant whose actor_ref does not match the current resource" do
    @harness.current_resource = clients(:one)
    token = ceremony_grant_token(operation: "link", actor_ref: "someone-else", session_ref: "session-1")

    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:store_social_ceremony_grant!, token)
    end
  end

  test "store_social_ceremony_grant! rejects a link grant whose session_ref does not match the current session" do
    @harness.current_resource = clients(:one)
    @harness.define_singleton_method(:current_session_public_id) { "real-session" }
    token = ceremony_grant_token(operation: "link", actor_ref: clients(:one).public_id, session_ref: "wrong-session")

    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:store_social_ceremony_grant!, token)
    end
  end

  test "social_ceremony_grant_token returns an inline jwt without a replay lookup" do
    @harness.session_hash[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY] = "header.payload.signature"

    assert_equal "header.payload.signature", @harness.send(:social_ceremony_grant_token)
  end

  test "social_ceremony_grant_token returns nil for an unknown replay transaction id" do
    @harness.session_hash[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY] = "unknown-transaction-id"

    assert_nil @harness.send(:social_ceremony_grant_token)
  end

  test "social_ceremony_grant_operation returns nil when no grant is stored" do
    assert_nil @harness.send(:social_ceremony_grant_operation)
  end

  test "social_auth_authorization_resource falls back to current_client when current_resource is absent" do
    harness = AuthorizationResourceHarness.new
    harness.current_client = clients(:one)

    assert_equal clients(:one), harness.send(:social_auth_authorization_resource)
  end

  test "social_auth_authorization_resource falls back to current_operator when current_client is absent" do
    harness = AuthorizationResourceHarness.new
    harness.current_operator = operators(:one)

    assert_equal operators(:one), harness.send(:social_auth_authorization_resource)
  end

  test "social_auth_authorization_resource falls back to current_visitor when current_operator is absent" do
    harness = AuthorizationResourceHarness.new
    harness.current_visitor = visitors(:reserved_visitor)

    assert_equal visitors(:reserved_visitor), harness.send(:social_auth_authorization_resource)
  end

  test "social_auth_authorization_resource returns nil when no resource is present" do
    harness = AuthorizationResourceHarness.new

    assert_nil harness.send(:social_auth_authorization_resource)
  end

  test "social_auth_request_path falls back to fullpath when path is unavailable" do
    fake_request = Object.new
    fake_request.define_singleton_method(:fullpath) { "/fallback/full/path" }
    @harness.request_obj = fake_request

    assert_equal "/fallback/full/path", @harness.send(:social_auth_request_path)
  end

  test "social_auth_request_path returns nil when neither path nor fullpath are available" do
    @harness.request_obj = Object.new

    assert_nil @harness.send(:social_auth_request_path)
  end

  test "social_auth_request_path returns nil when reading path raises" do
    fake_request = Object.new
    fake_request.define_singleton_method(:path) { raise StandardError, "boom" }
    @harness.request_obj = fake_request

    assert_nil @harness.send(:social_auth_request_path)
  end

  test "handle_record_not_unique renders json for json requests" do
    req = @harness.request
    req.define_singleton_method(:format) do
      Struct.new(:json?).new(true)
    end

    @harness.send(:handle_record_not_unique, StandardError.new("not unique"))

    assert_equal :conflict, @harness.rendered[:status]
  end

  test "social_auth_observability_surface classifies Sign::Com controllers as :com" do
    harness = Sign::Com::SocialAuthConcernSurfaceHarness.new

    assert_equal :com, harness.send(:social_auth_observability_surface)
  end

  test "social_auth_observability_surface classifies Sign::Org controllers as :org" do
    harness = Sign::Org::SocialAuthConcernSurfaceHarness.new

    assert_equal :org, harness.send(:social_auth_observability_surface)
  end

  test "social_auth_failure_redirect_path_for_intent falls back to the routed apple settings path" do
    harness = RouteFallbackHarness.new
    expected = Rails.application.routes.url_helpers.auth_app_settings_apple_path

    assert_equal expected,
                 harness.send(:social_auth_failure_redirect_path_for_intent, intent: "link", provider: "apple")
  end

  test "social_auth_failure_redirect_path_for_intent falls back to the routed settings path for non-apple providers" do
    harness = RouteFallbackHarness.new
    expected = Rails.application.routes.url_helpers.auth_app_settings_path

    assert_equal expected,
                 harness.send(:social_auth_failure_redirect_path_for_intent, intent: "link", provider: "google")
  end

  test "social_auth_failure_redirect_path falls back to root when no sign-in path is defined" do
    harness = RouteFallbackHarness.new

    assert_equal "/", harness.send(:social_auth_failure_redirect_path)
  end

  test "social_auth_success_redirect_path falls back to root when no root path is defined" do
    harness = RouteFallbackHarness.new

    assert_equal "/", harness.send(:social_auth_success_redirect_path)
  end

  test "validate_intent_ttl! is a no-op when no start time is recorded" do
    assert_nothing_raised do
      @harness.send(:validate_intent_ttl!, "google")
    end
  end

  test "validate_user_consistency! is a no-op for non-link intents" do
    assert_nothing_raised do
      @harness.send(:validate_user_consistency!, "login")
    end
  end

  test "validate_user_consistency! accepts a matching current user" do
    @harness.session_hash[SocialAuth::SOCIAL_USER_ID_SESSION_KEY] = clients(:one).id
    @harness.current_resource = clients(:one)

    assert_nothing_raised do
      @harness.send(:validate_user_consistency!, "link")
    end
  end

  test "store_social_auth_user_context clears the stored user id for non-link intents" do
    @harness.session_hash[SocialAuth::SOCIAL_USER_ID_SESSION_KEY] = 42

    @harness.send(:store_social_auth_user_context, "login")

    assert_nil @harness.session_hash[SocialAuth::SOCIAL_USER_ID_SESSION_KEY]
  end

  test "resolve_external_authentication_use_case raises for an unrecognized intent" do
    assert_raises(SocialAuth::UnauthorizedError) do
      @harness.send(:resolve_external_authentication_use_case, nil, "step_up")
    end
  end

  test "handle_social_auth_error classifies a state_expired error" do
    error = SocialAuth::UnauthorizedError.new("errors.social_auth.state_expired")
    logged =
      capture_error_context_log do
        @harness.send(:handle_social_auth_error, error)
      end

    assert_includes logged, "social_auth.state.expired"
  end

  test "handle_social_auth_error classifies a state_missing error" do
    error = SocialAuth::UnauthorizedError.new("errors.social_auth.state_missing")
    logged =
      capture_error_context_log do
        @harness.send(:handle_social_auth_error, error)
      end

    assert_includes logged, "social_auth.state.invalid"
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

  def capture_error_context_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end

  # Builds a real, verifiably-signed social ceremony grant JWT so
  # store_social_ceremony_grant! is exercised through its actual decode/verify
  # path rather than a stub.
  def ceremony_grant_token(operation:, actor_ref: "actor-#{SecureRandom.hex(4)}",
                           session_ref: "session-#{SecureRandom.hex(4)}", now: Time.current)
    claims = {
      "typ" => IdentitySocialCeremonyGrant::TOKEN_TYPE,
      "iss" => IdentitySocialCeremonyContract.acme_issuer("app"),
      "aud" => IdentitySocialCeremonyContract.sign_audience("app"),
      "purpose" => IdentitySocialCeremonyGrant::PURPOSE,
      "surface" => "app",
      "actor_ref" => actor_ref,
      "session_ref" => session_ref,
      "transaction_id" => "txn-#{SecureRandom.hex(4)}",
      "jti" => "grant-#{SecureRandom.hex(4)}",
      "operation" => operation,
      "provider" => "google",
      "iat" => now.to_i,
      "exp" => (now + 10.minutes).to_i,
    }
    IdentitySocialCeremonyGrant.issue(
      claims,
      issuer_id: IdentitySocialCeremonyContract.acme_issuer_id("app"),
      now: now,
    )
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
