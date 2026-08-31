# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignOrgVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include PreferenceGlobal
    include CommonOtp
    include AuthenticationOperator
    include VerificationOperator
    include PasskeyCeremonyContext
    include SignVerificationTiming
    include SignVerificationCommonBase
    include SignVerificationAuditAndCookie
    include SignVerificationStepUpSessionStore
    include SignVerificationStepUpLifecycle
    include SignVerificationPasskeyChecks
    include SignOrgVerificationBase
  end

  test "included do includes PreferenceGlobal module" do
    assert_includes Harness.included_modules, PreferenceGlobal
  end

  test "included do includes CommonOtp module" do
    assert_includes Harness.included_modules, CommonOtp
  end

  test "included do includes AuthenticationOperator module" do
    assert_includes Harness.included_modules, AuthenticationOperator
  end

  test "included do includes VerificationOperator module" do
    assert_includes Harness.included_modules, VerificationOperator
  end

  test "included do includes PasskeyCeremonyContext module" do
    assert_includes Harness.included_modules, PasskeyCeremonyContext
  end

  test "included do includes SignVerificationTiming module" do
    assert_includes Harness.included_modules, SignVerificationTiming
  end

  test "included do includes SignVerificationCommonBase module" do
    assert_includes Harness.included_modules, SignVerificationCommonBase
  end

  test "included do includes SignVerificationAuditAndCookie module" do
    assert_includes Harness.included_modules, SignVerificationAuditAndCookie
  end

  test "included do includes SignVerificationStepUpSessionStore module" do
    assert_includes Harness.included_modules, SignVerificationStepUpSessionStore
  end

  test "included do includes SignVerificationStepUpLifecycle module" do
    assert_includes Harness.included_modules, SignVerificationStepUpLifecycle
  end

  test "included do includes SignVerificationPasskeyChecks module" do
    assert_includes Harness.included_modules, SignVerificationPasskeyChecks
  end

  test "STEP_UP_TTL constant is defined" do
    assert_equal 15.minutes, SignOrgVerificationBase::STEP_UP_TTL
  end

  test "ALLOWED_SCOPES constant is defined" do
    assert_kind_of Hash, SignOrgVerificationBase::ALLOWED_SCOPES
    assert SignOrgVerificationBase::ALLOWED_SCOPES.key?("settings_passkey")
    assert SignOrgVerificationBase::ALLOWED_SCOPES.key?("settings_mfa")
  end
end

# Direct coverage of VerificationBase itself, exercised through the Org/Operator surface.
#
# The full Harness above pulls in SignVerificationStepUpLifecycle, SignVerificationAuditAndCookie,
# and friends, several of which declare their own abstract (NotImplementedError-raising)
# verification_model / current_verification_actor stand-ins that sit ahead of VerificationBase in the
# module chain and shadow it -- so calls against that Harness cannot reach VerificationBase's own
# code for those methods. This class instead builds a controller with only VerificationOperator
# (VerificationBase + actor_operator? == true, no further overrides), which reaches VerificationBase's
# own method bodies directly for every call below.
#
# Rendering: assigning a fresh ActionDispatch::TestResponse to a controller that was never dispatched
# through #process already reports #performed? as true in this app's Rails version, so a real
# render/redirect_to call here always raises AbstractController::DoubleRenderError regardless of what
# preceded it. Tests that need to observe a render/redirect stub the method via
# define_singleton_method and assert on the captured arguments instead, matching the existing pattern
# in test/controllers/concerns/authentication/base_coverage_test.rb.
class SignOrgVerificationBaseDirectCoverageTest < ActiveSupport::TestCase
  test "clear_verification_requirement! resets the required verification scope" do
    harness = build_verification_base_harness
    harness.send(:require_verification!, :settings_passkey)

    assert_equal :settings_passkey, harness.send(:verification_scope)

    harness.send(:clear_verification_requirement!)

    assert_nil harness.send(:verification_scope)
    assert_nil harness.send(:verification_requirement)
  end

  test "verification_satisfied? returns false when there is no actor token" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session) { nil }
    harness.define_singleton_method(:current_session_public_id) { nil }

    assert_not harness.send(:verification_satisfied?)
  end

  test "verification_satisfied? delegates to the verification cookie record when no step-up scope is required" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session) { nil }
    harness.define_singleton_method(:current_session_public_id) { token.public_id }
    harness.send(:cookies)[OperatorVerification.cookie_name] = raw_token

    assert harness.send(:verification_satisfied?)
  end

  test "verification_record_satisfied? returns false when the verification cookie is missing" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    harness = build_verification_base_harness

    assert_not harness.send(:verification_record_satisfied?, token)
  end

  test "verification_record_satisfied? returns false when the cookie does not match a verification record" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    harness = build_verification_base_harness
    harness.send(:cookies)[OperatorVerification.cookie_name] = "not-a-real-token"

    assert_not harness.send(:verification_record_satisfied?, token)
  end

  test "verification_record_satisfied? returns true and stamps last_used_at when the cookie matches" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    harness = build_verification_base_harness
    harness.send(:cookies)[OperatorVerification.cookie_name] = raw_token

    assert harness.send(:verification_record_satisfied?, token)
    assert_in_delta Time.current, OperatorVerification.active.find_by!(staff_token_id: token.id).last_used_at, 5.seconds
  end

  test "verification_model resolves OperatorVerification for operator actors" do
    harness = build_verification_base_harness

    assert_equal OperatorVerification, harness.send(:verification_model)
  end

  test "verification_token_foreign_key resolves staff_token_id for operator actors" do
    harness = build_verification_base_harness

    assert_equal :staff_token_id, harness.send(:verification_token_foreign_key)
  end

  test "current_session_token looks up the token record via token_class when current_session is absent" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session) { nil }
    harness.define_singleton_method(:current_session_public_id) { token.public_id }

    assert_equal token, harness.send(:current_session_token)
  end

  test "current_actor_token returns the token record when it is currently usable" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session) { nil }
    harness.define_singleton_method(:current_session_public_id) { token.public_id }

    assert_equal token, harness.send(:current_actor_token)
  end

  test "current_actor_token returns nil when the located token record is not currently usable" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    token.update_columns(discarded_at: 1.minute.ago)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session) { nil }
    harness.define_singleton_method(:current_session_public_id) { token.public_id }

    assert_nil harness.send(:current_actor_token)
  end

  test "current_actor_token returns nil when there is no current session public id" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session) { nil }
    harness.define_singleton_method(:current_session_public_id) { nil }

    assert_nil harness.send(:current_actor_token)
  end

  test "current_actor_token memoizes the resolved token across repeated calls" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session) { nil }
    harness.define_singleton_method(:current_session_public_id) { token.public_id }

    first = harness.send(:current_actor_token)
    second = harness.send(:current_actor_token)

    assert_same first, second
  end

  test "available_step_up_methods memoizes the resolved value when there is no explicit actor" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_verification_actor) { nil }

    first = harness.send(:available_step_up_methods)
    second = harness.send(:available_step_up_methods)

    assert_equal [], first
    assert_same first, second
  end

  test "configured_step_up_methods memoizes the resolved value when there is no explicit actor" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_verification_actor) { nil }

    first = harness.send(:configured_step_up_methods)
    second = harness.send(:configured_step_up_methods)

    assert_equal [], first
    assert_same first, second
  end

  test "step_up_bootstrap_unconfigured? returns false when there is no verification actor" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_verification_actor) { nil }

    assert_not harness.send(:step_up_bootstrap_unconfigured?)
  end

  test "step_up_bootstrap_active? falls back to configured methods when the actor has no mfa status flag" do
    harness = build_verification_base_harness
    actor = Struct.new(:id).new(1)

    harness.stub(:configured_step_up_methods, [:passkey]) do
      assert harness.send(:step_up_bootstrap_active?, actor)
    end
  end

  test "current_step_up_ticket returns nil when the session token has no step_up_session method" do
    harness = build_verification_base_harness
    bare_token = Object.new
    harness.define_singleton_method(:current_session_token) { bare_token }

    assert_nil harness.send(:current_step_up_ticket)
  end

  test "refresh_actor_mfa_status does nothing when the actor cannot refresh its mfa status" do
    harness = build_verification_base_harness
    actor = Object.new

    assert_nil harness.send(:refresh_actor_mfa_status, actor)
  end

  test "refresh_actor_mfa_status does nothing for a destroyed actor" do
    harness = build_verification_base_harness
    actor =
      Class.new do
        def refresh_mfa_status!
          raise RuntimeError, "should not be called"
        end

        def destroyed?
          true
        end
      end.new

    assert_nil harness.send(:refresh_actor_mfa_status, actor)
  end

  test "signed_pt_to_safe_path returns nil when the controller class has no recognizable surface" do
    harness = build_verification_base_harness

    assert_nil harness.send(:signed_pt_to_safe_path, "some-token")
  end

  test "step_up_session_revoked? returns true when there is no session token" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session_token) { nil }

    assert harness.send(:step_up_session_revoked?)
  end

  test "step_up_session_revoked? renders session expired and returns true for a dead token" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    token.update_columns(discarded_at: 1.minute.ago)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session_token) { token }
    rendered = nil
    harness.define_singleton_method(:render) { |**kwargs| rendered = kwargs }

    assert harness.send(:step_up_session_revoked?)
    assert_equal :unauthorized, rendered[:status]
    assert_equal I18n.t("auth.session_expired"), rendered[:plain]
  end

  test "step_up_session_revoked? logs out when the controller supports log_out" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    token.update_columns(discarded_at: 1.minute.ago)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session_token) { token }
    harness.define_singleton_method(:render) { |**| nil }
    logged_out = false
    harness.define_singleton_method(:log_out) { logged_out = true }

    assert harness.send(:step_up_session_revoked?)
    assert logged_out
  end

  test "require_step_up! returns nil without side effects when step-up is already satisfied" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session_token) { token }
    harness.define_singleton_method(:step_up_satisfied?) { |**| true }

    assert_nil harness.send(:require_step_up!, scope: :settings_passkey)
  end

  test "require_step_up! returns false immediately when the step-up session is revoked" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session_token) { nil }

    assert_not harness.send(:require_step_up!, scope: :settings_passkey)
  end

  test "issue_step_up_pt returns nil when the safe path fails internal-path validation despite a resolvable surface" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:bootstrap_pt_surface) { "org" }
    harness.define_singleton_method(:current_session_public_id) { "session-nonce-value" }

    assert_nil harness.send(:issue_step_up_pt, "not-a-safe-path")
  end

  test "require_step_up! redirects to the verification path for a GET request when step-up is not satisfied" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session_token) { token }
    harness.define_singleton_method(:enforce_step_up_prereqs!) { |**| true }
    redirected = nil
    harness.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected = [args, kwargs] }

    result = harness.send(:require_step_up!, scope: :settings_passkey)

    assert_not result
    assert_match %r{/verification\?}, redirected[0][0]
  ensure
    Actor.reset
  end

  test "require_step_up! logs the installed step-up context including a computed expiry" do
    staff = operators(:one)
    token = OperatorToken.create!(staff: staff)
    token.update_columns(last_step_up_at: 1.minute.ago, last_step_up_scope: "unrelated_scope")
    harness = build_verification_base_harness
    harness.define_singleton_method(:current_session_token) { token }
    harness.define_singleton_method(:enforce_step_up_prereqs!) { |**| true }
    harness.define_singleton_method(:redirect_to) { |*, **| nil }

    result = harness.send(:require_step_up!, scope: :settings_passkey)

    assert_not result
    assert_predicate Actor.step_up.expires_at, :present?
  ensure
    Actor.reset
  end

  test "handle_unverified_actor! renders a json error for a non-GET json request when unverified" do
    harness = build_verification_base_harness
    harness.request.request_method = "POST"
    harness.request.set_header("HTTP_ACCEPT", "application/json")
    rendered = nil
    harness.define_singleton_method(:render) { |**kwargs| rendered = kwargs }

    harness.send(:handle_unverified_actor!)

    assert_equal :unauthorized, rendered[:status]
    assert_equal({ error: VerificationBase::STEP_UP_REQUIRED_MESSAGE }, rendered[:json])
  end

  test "enforce_step_up_prereqs! allows a GET request to the verification entry page when methods are " \
       "configured but unavailable" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:available_step_up_methods) { [] }
    harness.define_singleton_method(:configured_step_up_methods) { [:passkey] }
    entry_path = harness.send(:actor_verification_path)
    harness.request.set_header("PATH_INFO", entry_path)

    assert harness.send(:enforce_step_up_prereqs!)
  end

  test "enforce_step_up_prereqs! renders json error for a non-GET json request when step-up methods are unavailable" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:available_step_up_methods) { [] }
    harness.request.request_method = "POST"
    harness.request.set_header("HTTP_ACCEPT", "application/json")
    rendered = nil
    harness.define_singleton_method(:render) { |**kwargs| rendered = kwargs }

    assert_not harness.send(:enforce_step_up_prereqs!)
    assert_equal :unprocessable_content, rendered[:status]
  end

  test "enforce_step_up_prereqs! redirects to the verification path for a non-GET html request when step-up is " \
       "configured" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:available_step_up_methods) { [] }
    harness.define_singleton_method(:step_up_bootstrap_unconfigured?) { false }
    harness.request.request_method = "POST"
    harness.request.set_header("HTTP_ACCEPT", "text/html")
    redirected = nil
    harness.define_singleton_method(:redirect_to) { |*args, **kwargs| redirected = [args, kwargs] }

    result = harness.send(:enforce_step_up_prereqs!, scope_override: :settings_passkey)

    assert_not result
    assert_match %r{/verification\?}, redirected[0][0]
    assert_equal :see_other, redirected[1][:status]
  end

  test "setup_pt_path redirects settings sub-paths to the provided root path" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:decode_pt_path) { |_encoded| "/settings/emails" }

    assert_equal "/root", harness.send(:setup_pt_path, "encoded", root_path: "/root")
  end

  test "setup_pt_path returns the decoded path when it is not a settings sub-path" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:decode_pt_path) { |_encoded| "/dashboard" }

    assert_equal "/dashboard", harness.send(:setup_pt_path, "encoded", root_path: "/root")
  end

  test "setup_pt_path returns the root settings path unchanged when it already equals root_path" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:decode_pt_path) { |_encoded| "/settings/" }

    assert_equal "/settings/", harness.send(:setup_pt_path, "encoded", root_path: "/settings/")
  end

  test "setup_pt_path returns nil when the decoded path is not a valid URI" do
    harness = build_verification_base_harness
    harness.define_singleton_method(:decode_pt_path) { |_encoded| "http://[invalid" }

    assert_nil harness.send(:setup_pt_path, "encoded", root_path: "/root")
  end

  test "unwrap_verification_pt_path stops when the verification path has no pt query parameter" do
    harness = build_verification_base_harness
    path = harness.send(:actor_verification_path)

    assert_equal path, harness.send(:unwrap_verification_pt_path, path)
  end

  test "unwrap_verification_pt_path stops when the nested pt token does not resolve" do
    harness = build_verification_base_harness
    path = "#{harness.send(:actor_verification_path)}?pt=bogus"
    harness.define_singleton_method(:resolve_step_up_pt) { |_encoded| nil }

    assert_equal path, harness.send(:unwrap_verification_pt_path, path)
  end

  test "unwrap_verification_pt_path returns the last safe path when the nested pt cannot be parsed as a URI" do
    harness = build_verification_base_harness
    path = "#{harness.send(:actor_verification_path)}?pt=bogus"
    harness.define_singleton_method(:resolve_step_up_pt) { |_encoded| "http://[invalid" }

    assert_equal "http://[invalid", harness.send(:unwrap_verification_pt_path, path)
  end

  private

  def build_verification_base_harness
    harness = Class.new(ApplicationController) { include VerificationOperator }.new
    harness.request = ActionDispatch::TestRequest.create
    harness.response = ActionDispatch::TestResponse.new
    # The minimal VerificationOperator-only harness has no AuthenticationOperator, so
    # current_session_public_id/token_class (referenced unconditionally, not behind a respond_to?
    # guard, by several VerificationBase methods) would otherwise raise NameError. Tests that care
    # about a specific public id/session override these again afterwards.
    harness.define_singleton_method(:current_session_public_id) { nil }
    harness.define_singleton_method(:token_class) { OperatorToken }
    harness
  end
end
