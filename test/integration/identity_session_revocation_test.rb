# typed: false
# frozen_string_literal: true

require "test_helper"

# Self-service session management on the app and com browser surfaces:
# listing sessions, revoking one selected session, revoking every other
# session, and revoking all sessions.
#
# The org surface runs the same controllers with an operator actor. It is
# covered at the service level in
# `test/services/authentication_other_sessions_revoker_test.rb` instead,
# because org HTML requests without an OIDC RP browser session are answered
# by the SSO initiator before any controller under test runs.
#
# "Revoke all" is account-wide and destructive, so it sits behind the
# `session_revoke_all` step-up scope the catalog reserves for it and runs
# through the `logout_all_sessions_for!` chokepoint (session-version bump,
# logout audit, cookie clear, Rails session reset). Selected/other revokes
# stay step-up free: they cannot lock the actor out of the surface they are
# currently using.
class IdentitySessionRevocationTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    ensure_token_reference_records!

    @app_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @com_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
  end

  # --- app surface -------------------------------------------------------

  test "app session index renders the revoke controls when other sessions exist" do
    host! @app_host
    setup_app_actor!

    get base_app_identity_sessions_url(ri: "jp", host: @app_host), headers: @app_headers

    assert_response :success
    assert_match "/identity/other_sessions", response.body
    assert_match @other_token.public_id, response.body
  end

  test "app revoke selected session revokes only that session" do
    host! @app_host
    setup_app_actor!

    delete base_app_identity_session_url(@other_token.public_id, ri: "jp", host: @app_host), headers: @app_headers

    assert_response :see_other
    assert_not_predicate @other_token.reload, :currently_usable?
    assert_predicate @current_token.reload, :currently_usable?
  end

  test "app revoke selected session refuses to revoke the current session" do
    host! @app_host
    setup_app_actor!

    delete base_app_identity_session_url(@current_token.public_id, ri: "jp", host: @app_host), headers: @app_headers

    assert_response :see_other
    assert_predicate @current_token.reload, :currently_usable?
  end

  test "app revoke other sessions keeps the current session" do
    host! @app_host
    setup_app_actor!

    delete base_app_identity_other_sessions_url(ri: "jp", host: @app_host), headers: @app_headers

    assert_response :see_other
    assert_not_predicate @other_token.reload, :currently_usable?
    assert_predicate @current_token.reload, :currently_usable?
  end

  test "app revoke all is rejected without step-up and leaves sessions active" do
    host! @app_host
    setup_app_actor!

    delete base_app_identity_session_set_url(ri: "jp", host: @app_host), headers: @app_headers

    assert_response :unauthorized
    assert_predicate @current_token.reload, :currently_usable?
    assert_predicate @other_token.reload, :currently_usable?
  end

  test "app revoke all with a step-up for another scope is still rejected" do
    host! @app_host
    setup_app_actor!
    satisfy_client_verification(@current_token)
    mark_step_up_satisfied!(@current_token, scope: "settings_email", audience: "step_up:app")

    delete base_app_identity_session_set_url(ri: "jp", host: @app_host), headers: @app_headers

    assert_response :unauthorized
    assert_predicate @other_token.reload, :currently_usable?
  end

  test "app revoke all revokes every session once step-up is satisfied" do
    host! @app_host
    setup_app_actor!
    satisfy_client_verification(@current_token)
    mark_step_up_satisfied!(@current_token, scope: "session_revoke_all", audience: "step_up:app")

    delete base_app_identity_session_set_url(ri: "jp", host: @app_host), headers: @app_headers

    assert_response :see_other
    assert_not_predicate @current_token.reload, :currently_usable?
    assert_not_predicate @other_token.reload, :currently_usable?
  end

  # --- com surface -------------------------------------------------------

  test "com session index renders the revoke controls when other sessions exist" do
    host! @com_host
    setup_com_actor!

    get base_com_identity_sessions_url(ri: "jp", host: @com_host), headers: @com_headers

    assert_response :success
    assert_match "/identity/other_sessions", response.body
    assert_match @other_token.public_id, response.body
  end

  test "com revoke other sessions keeps the current session" do
    host! @com_host
    setup_com_actor!

    delete base_com_identity_other_sessions_url(ri: "jp", host: @com_host), headers: @com_headers

    assert_response :see_other
    assert_not_predicate @other_token.reload, :currently_usable?
    assert_predicate @current_token.reload, :currently_usable?
  end

  test "com revoke all is rejected without step-up" do
    host! @com_host
    setup_com_actor!

    delete base_com_identity_session_set_url(ri: "jp", host: @com_host), headers: @com_headers

    assert_step_up_challenged
    assert_predicate @current_token.reload, :currently_usable?
    assert_predicate @other_token.reload, :currently_usable?
  end

  test "com revoke all revokes every session once step-up is satisfied" do
    host! @com_host
    setup_com_actor!
    satisfy_visitor_verification(@current_token)
    mark_step_up_satisfied!(@current_token, scope: "session_revoke_all", audience: "step_up:com")

    delete base_com_identity_session_set_url(ri: "jp", host: @com_host), headers: @com_headers

    assert_response :see_other
    assert_not_predicate @current_token.reload, :currently_usable?
    assert_not_predicate @other_token.reload, :currently_usable?
  end

  # The org controller's HTTP path is not exercisable here (see the note at the
  # top of this file), so pin its step-up declaration structurally: the scope
  # must stay the one `StepUpScopeCatalog` reserves, on every surface.
  test "every surface declares the session_revoke_all step-up scope" do
    [
      Base::App::Identity::Revocations::AllsController,
      Base::Com::Identity::Revocations::AllsController,
      Base::Org::Identity::Revocations::AllsController,
    ].each do |controller_class|
      assert_equal "session_revoke_all", controller_class.new.send(:verification_scope),
                   "#{controller_class} must gate revoke-all on the session_revoke_all scope"
    end

    assert StepUpScopeCatalog::APP.key?("session_revoke_all")
    assert StepUpScopeCatalog::COM.key?("session_revoke_all")
    assert StepUpScopeCatalog::ORG.key?("session_revoke_all")
  end

  private

  # A revoke-all attempt without satisfied step-up is either answered with 401
  # (step-up possible for this actor) or redirected into the verification flow
  # (actor still has to set a step-up credential up). Both mean "not revoked".
  def assert_step_up_challenged
    return assert_response(:unauthorized) if response.status == 401

    assert_response :redirect
    assert_match %r{\A/verification}, URI.parse(response.location).path
  end

  def setup_app_actor!
    @actor = clients(:one)
    @current_token = create_client_token
    @other_token = create_client_token
    @app_headers = bearer_session_headers(@actor, @current_token, host: @app_host, resource_type: "client")
  end

  # Reference rows the token/actor records depend on. Kept local and minimal:
  # only the ids this test actually writes.
  def ensure_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::NOTHING)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::NOTHING)
    VisitorTokenBindingMethod.ensure_defaults!
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def setup_com_actor!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    @actor = Visitor.create!(
      status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
    )
    @current_token = create_visitor_token
    @other_token = create_visitor_token
    @com_headers = bearer_session_headers(@actor, @current_token, host: @com_host, resource_type: "visitor")
  end

  def bearer_session_headers(actor, token, host:, resource_type:)
    bearer_headers(
      jwt_access_token_for(actor, host: host, session_public_id: token.public_id, resource_type: resource_type),
      host: host,
    ).merge("X-TEST-SESSION-PUBLIC-ID" => token.public_id)
  end

  def create_client_token
    token = ClientToken.create!(
      user: @actor,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "revoke_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    token.update!(created_at: 1.hour.ago)
    token
  end

  def create_visitor_token
    token = VisitorToken.create!(
      visitor: @actor,
      visitor_token_status_id: VisitorTokenStatus::NOTHING,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      public_id: "revoke_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    token.update!(created_at: 1.hour.ago)
    token
  end

  def satisfy_client_verification(token)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
  end

  def satisfy_visitor_verification(token)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
  end

  def mark_step_up_satisfied!(token, scope:, audience:, at: 1.minute.ago, method: "passkey", aal: "aal2")
    token.update!(
      last_step_up_at: at,
      last_step_up_scope: scope,
      last_step_up_aal: aal,
      last_step_up_method: method,
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (audience if token.respond_to?(:last_step_up_audience)),
    )
  end
end
