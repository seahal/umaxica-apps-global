# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialAuthConcernTest < ActiveSupport::TestCase
  StepUpToken =
    Struct.new(
      :currently_usable,
      :public_id,
      :last_step_up_at,
      :last_step_up_scope,
      :last_step_up_aal,
      :last_step_up_method,
      :last_step_up_session_public_id,
      :last_step_up_purpose,
      :last_step_up_audience,
      keyword_init: true,
    ) do
      def currently_usable? = currently_usable

      def has_attribute?(attribute)
        members.include?(attribute.to_sym)
      end
    end

  class Harness
    class << self
      def rescue_from(*) = nil
    end

    include SocialAuthConcern

    attr_accessor :session_hash, :params_hash, :request_object, :resource, :logged_in_value, :session_token

    def initialize
      @session_hash = {}
      @params_hash = {}
      @request_object = ActionDispatch::TestRequest.create("PATH_INFO" => "/auth/apple/callback")
      @logged_in_value = false
    end

    def session = session_hash

    def params = params_hash.with_indifferent_access

    def request = request_object

    def logged_in? = logged_in_value

    def current_resource = resource

    def current_session_token = session_token

    def resource_class = Client

    def sign_app_settings_path = "/settings"

    def sign_app_settings_apple_path = "/settings/apple"

    def new_sign_app_sign_in_path = "/sign/in"

    def sign_app_root_path = "/"
  end

  test "prepare social auth intent stores login context and rejects invalid intent" do
    harness = Harness.new

    state = harness.send(
      :prepare_social_auth_intent!,
      "login",
      provider: "google",
      pt: "encoded-pt",
      entry: "sign_up",
      ri: "jp",
    )

    assert_predicate state, :present?
    assert_equal "login", harness.session_hash[SocialAuthConcern::SOCIAL_INTENT_SESSION_KEY]
    assert_equal "google", harness.session_hash[SocialAuthConcern::SOCIAL_PROVIDER_SESSION_KEY]
    assert_equal "encoded-pt", harness.session_hash[SocialAuthConcern::SOCIAL_PT_SESSION_KEY]
    assert_equal "encoded-pt", harness.send(:current_social_auth_pt)
    assert_equal "sign_up", harness.send(:current_social_auth_entry)
    assert_equal "jp", harness.send(:current_social_auth_ri)
    assert_nil harness.session_hash[SocialAuthConcern::SOCIAL_USER_ID_SESSION_KEY]

    assert_raises(SocialAuth::UnauthorizedError) do
      harness.send(:prepare_social_auth_intent!, "bad")
    end
  end

  test "prepare social auth intent requires login for link and stores user id" do
    harness = Harness.new

    assert_raises(SocialAuth::UnauthorizedError) do
      harness.send(:prepare_social_auth_intent!, "link", provider: "apple")
    end

    harness.logged_in_value = true
    harness.resource = clients(:one)
    harness.session_token = step_up_token(scope: SocialAuthConcern::SOCIAL_LINK_SCOPE)
    harness.send(:prepare_social_auth_intent!, "link", provider: "apple")

    assert_equal clients(:one).id, harness.session_hash[SocialAuthConcern::SOCIAL_USER_ID_SESSION_KEY]
  end

  test "prepare social auth link intent rejects resource-level step up without token-bound step up" do
    harness = Harness.new
    harness.logged_in_value = true
    harness.resource = clients(:one)
    harness.resource.update!(last_step_up_at: Time.current)

    assert_raises(SocialAuth::StepUpRequiredError) do
      harness.send(:prepare_social_auth_intent!, "link", provider: "apple")
    end

    assert_nil harness.session_hash[SocialAuthConcern::SOCIAL_USER_ID_SESSION_KEY]
  end

  test "validate social auth state handles login missing expired and user mismatch" do
    harness = Harness.new

    assert_nil harness.send(:validate_social_auth_state!)

    harness.session_hash[SocialAuthConcern::SOCIAL_INTENT_SESSION_KEY] = "link"
    assert_raises(SocialAuth::UnauthorizedError) { harness.send(:validate_social_auth_state!) }

    harness.session_hash[SocialAuthConcern::SOCIAL_FLOW_ID_SESSION_KEY] = "flow"
    harness.session_hash[SocialAuthConcern::SOCIAL_STARTED_AT_SESSION_KEY] = 10.minutes.ago.to_i
    assert_raises(SocialAuth::UnauthorizedError) { harness.send(:validate_social_auth_state!) }

    harness.session_hash[SocialAuthConcern::SOCIAL_STARTED_AT_SESSION_KEY] = Time.current.to_i
    harness.session_hash[SocialAuthConcern::SOCIAL_USER_ID_SESSION_KEY] = clients(:one).id
    harness.resource = clients(:two)
    assert_raises(SocialAuth::UnauthorizedError) { harness.send(:validate_social_auth_state!) }
  end

  test "social auth helpers clear session and resolve paths" do
    harness = Harness.new
    harness.logged_in_value = true
    harness.resource = clients(:one)
    harness.session_token = step_up_token(scope: SocialAuthConcern::SOCIAL_LINK_SCOPE)
    harness.send(:prepare_social_auth_intent!, "link", provider: "apple")

    assert_equal "link", harness.send(:current_social_auth_intent)
    assert_equal "/auth/google?state=abc+123", harness.send(:omniauth_authorize_path, "google", state: "abc 123")
    assert_equal "/auth/google", harness.send(:omniauth_authorize_path, "google")
    assert_equal clients(:one), harness.send(:social_auth_user)
    assert_equal "/", harness.send(:social_auth_success_redirect_path)
    assert_equal "/settings/apple",
                 harness.send(:social_auth_failure_redirect_path_for_intent, intent: "link", provider: "apple")
    assert_equal "/settings",
                 harness.send(:social_auth_failure_redirect_path_for_intent, intent: "link", provider: "google")

    harness.send(:clear_social_auth_intent!)

    assert_equal "login", harness.send(:current_social_auth_intent)
    assert_nil harness.send(:current_social_auth_pt)
    assert_nil harness.send(:current_social_auth_entry)
    assert_nil harness.send(:current_social_auth_ri)
    assert_nil harness.session_hash[SocialAuthConcern::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "process social auth callback returns pt before clearing session" do
    harness = Harness.new
    harness.send(:prepare_social_auth_intent!, "login", provider: "google", pt: "encoded-pt")

    SocialAuthService.stub(:handle_callback, ->(**) { { user: clients(:one), existing_account: true } }) do
      result = harness.send(:process_social_auth_callback)

      assert_equal "encoded-pt", result[:pt]
    end

    assert_nil harness.session_hash[SocialAuthConcern::SOCIAL_PT_SESSION_KEY]
  end

  test "grantless app social link is rejected and only a grant lifts the rejection" do
    harness = Harness.new

    # A grantless "link" callback must be rejected: final link commit is acme
    # authority and only flows through an acme-issued ceremony grant.
    assert_raises(SocialAuth::UnauthorizedError) do
      harness.send(:reject_grantless_app_social_link!, "link")
    end

    # Non-link intents are unaffected by the link guard.
    assert_nil harness.send(:reject_grantless_app_social_link!, "login")

    # With an acme grant in session the guard no longer fires; the grant-backed
    # link branch (which renders the acme completion form) handles it instead.
    issuance = Identity::SocialCeremony::GrantIssuer.issue!(
      surface: "app",
      actor_ref: "anonymous",
      session_ref: "session-ref",
      operation: "link",
      provider: "google_app",
    )
    harness.session_hash[SocialAuthConcern::SOCIAL_CEREMONY_GRANT_SESSION_KEY] = issuance.grant

    assert_nil harness.send(:reject_grantless_app_social_link!, "link")
  end

  test "grantless established social login callback does not create a sign-side session" do
    user = Client.create!(
      status_id: ClientStatus::ACTIVE, public_id: "estab_#{SecureRandom.hex(4)}",
      birthdate: "2000-02-03",
    )
    uid = "established_google_#{SecureRandom.hex(4)}"
    ClientGoogleIdentity.create!(
      user: user,
      uid: uid,
      provider: "google_app",
      token: "tok",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    harness = Harness.new
    harness.send(:prepare_social_auth_intent!, "login", provider: "google_app")
    # Simulate a grantless callback: drop the auto-issued login grant from session.
    harness.session_hash.delete(SocialAuthConcern::SOCIAL_CEREMONY_GRANT_SESSION_KEY)
    harness.request_object.set_header("omniauth.auth", OmniAuth::AuthHash.new(provider: "google_app", uid: uid))

    # The sign-side inline commit must never run for an established grantless login.
    committed = false

    SocialAuthService.stub(:handle_callback, ->(**) { committed = true; { user: user } }) do
      assert_raises(SocialAuth::UnauthorizedError) do
        harness.send(:process_social_auth_callback)
      end
    end

    assert_not committed, "sign must not establish a session for a grantless established social login"
  end

  test "grantless unknown social login still falls through to compatibility signup" do
    harness = Harness.new
    harness.send(:prepare_social_auth_intent!, "login", provider: "google_app")
    harness.session_hash.delete(SocialAuthConcern::SOCIAL_CEREMONY_GRANT_SESSION_KEY)
    harness.request_object.set_header(
      "omniauth.auth",
      OmniAuth::AuthHash.new(provider: "google_app", uid: "unknown_#{SecureRandom.hex(4)}"),
    )

    handled = false
    SocialAuthService.stub(:handle_callback, ->(**) { handled = true; { user: nil, existing_account: nil } }) do
      harness.send(:process_social_auth_callback)
    end

    assert handled, "unknown social signup remains bounded-legacy compatibility on sign"
  end

  private

  def step_up_token(scope:, at: Time.current, public_id: SecureRandom.hex(12))
    StepUpToken.new(
      currently_usable: true,
      public_id: public_id,
      last_step_up_at: at,
      last_step_up_scope: scope,
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: public_id,
      last_step_up_purpose: "step_up",
    )
  end
end
