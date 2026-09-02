# typed: false
# frozen_string_literal: true

require "test_helper"

# A step-up email code page can be reloaded with the scope and path target still
# in the query string, which is how the session is rebuilt after a token
# rotation. A request that names neither, or one the step-up store refuses, must
# report that no session was restored rather than raise into the page.
class SignEmailOtpVerificationSupportTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(scope:, pt:, &definition)
    Class.new do
      include SignEmailOtpVerificationSupport

      define_method(:incoming_scope) { scope }
      define_method(:incoming_pt) { pt }

      attr_reader :started

      def start_step_up_session!(**arguments)
        @started = arguments
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new
  end

  test "a request that names both a scope and a path target restores the session" do
    subject = harness(scope: "settings_email", pt: "signed-pt")

    assert subject.invoke(:restore_step_up_session_from_params!)
    assert_equal({ scope: "settings_email", pt_param: "signed-pt" }, subject.started)
  end

  test "a request that names neither restores nothing" do
    assert_not harness(scope: nil, pt: nil).invoke(:restore_step_up_session_from_params!)
  end

  test "a request the step-up store refuses restores nothing rather than raising" do
    subject =
      harness(scope: "settings_email", pt: "signed-pt") do
        def start_step_up_session!(**) = raise(ActionController::BadRequest, "invalid pt")
      end

    assert_not subject.invoke(:restore_step_up_session_from_params!)
  end

  # The submitted code is checked in four steps, each with its own message, so a
  # caller can tell "wrong code" from "code expired" from "ask for a new one" --
  # and none of them reveals whether the address behind the ceremony exists.
  def verifier(code:, data: { "otp_digest" => "digest" }, expired: false, matches: true)
    Class.new do
      include SignEmailOtpVerificationSupport

      define_method(:verification_params) { { code: code } }
      define_method(:raw_email_otp_session_data) { data }
      define_method(:current_step_up_session) do
        Struct.new(:discarded_at).new(expired ? 1.minute.ago : 1.hour.from_now)
      end
      define_method(:secure_email_otp_match?) { |_expected, _code| matches }

      def errors = @verification_errors

      def invoke(name, ...) = send(name, ...)
    end.new
  end

  test "a code that is not six digits is rejected as malformed" do
    subject = verifier(code: "abc")

    assert_not subject.invoke(:verify_email_otp!)
    assert_includes subject.errors, I18n.t("sign.app.verification.errors.invalid_code")
  end

  test "a ceremony with no stored code asks for a new one" do
    subject = verifier(code: "123456", data: nil)

    assert_not subject.invoke(:verify_email_otp!)
    assert_includes subject.errors, I18n.t("sign.app.verification.errors.resend_required")
  end

  test "a ceremony whose window has closed reports the code as expired" do
    subject = verifier(code: "123456", expired: true)

    assert_not subject.invoke(:verify_email_otp!)
    assert_includes subject.errors, I18n.t("sign.app.verification.errors.code_expired")
  end

  test "a code that does not match the stored digest is rejected as incorrect" do
    subject = verifier(code: "123456", matches: false)

    assert_not subject.invoke(:verify_email_otp!)
    assert_includes subject.errors, I18n.t("sign.app.verification.errors.incorrect_code")
  end

  test "a code that matches the stored digest inside the window is accepted" do
    assert verifier(code: "123456").invoke(:verify_email_otp!)
  end

  # The scope and path target are read from the nested `verification` form when
  # the page posts, and from the top-level query string when the page is merely
  # reloaded. Both carriers have to answer, because the reload is how a session
  # survives a token rotation.
  def reader(params)
    Class.new do
      include SignEmailOtpVerificationSupport

      define_method(:params) { ActionController::Parameters.new(params) }

      def invoke(name, ...) = send(name, ...)
    end.new
  end

  test "the scope and path target are read from a posted verification form" do
    subject = reader(ri: "jp", verification: { scope: "settings_email", pt: "form-pt" })

    assert_equal "settings_email", subject.invoke(:incoming_scope)
    assert_equal "form-pt", subject.invoke(:incoming_pt)
  end

  test "the scope and path target fall back to the top-level query string on a reload" do
    subject = reader(ri: "jp", scope: "settings_telephone", pt: "query-pt")

    assert_equal "settings_telephone", subject.invoke(:incoming_scope)
    assert_equal "query-pt", subject.invoke(:incoming_pt)
  end

  test "a request naming neither carrier reports no scope and no path target" do
    subject = reader(ri: "jp")

    assert_nil subject.invoke(:incoming_scope)
    assert_nil subject.invoke(:incoming_pt)
  end

  # Recovering from a failed code has to land back on the same ceremony, so the
  # redirect carries the scope and path target forward -- but only when they were
  # supplied, so a bare recovery link stays bare rather than growing empty keys.
  test "the recovery redirect carries the scope and path target forward" do
    subject = reader(ri: "jp", verification: { scope: "settings_email", pt: "form-pt" })

    assert_equal(
      { ri: "jp", scope: "settings_email", pt: "form-pt" },
      subject.invoke(:verification_recovery_redirect_params),
    )
  end

  test "the recovery redirect carries only the region when nothing else was supplied" do
    assert_equal({ ri: "jp" }, reader(ri: "jp").invoke(:verification_recovery_redirect_params))
  end

  # The stored digest is bound to the step-up session id, so a code that is right
  # for one ceremony is wrong for another. A ceremony that stored no digest at all
  # matches nothing rather than comparing against an empty string.
  def matcher(session_id: "step-up-1")
    Class.new do
      include SignEmailOtpVerificationSupport

      define_method(:current_step_up_session) { Struct.new(:id).new(session_id) }

      def invoke(name, ...) = send(name, ...)
    end.new
  end

  test "a code matching the digest stored for this ceremony is accepted" do
    subject = matcher
    digest = subject.invoke(:email_otp_digest, "123456")

    assert subject.invoke(:secure_email_otp_match?, digest, "123456")
  end

  test "a code that does not produce the stored digest is refused" do
    subject = matcher
    digest = subject.invoke(:email_otp_digest, "123456")

    assert_not subject.invoke(:secure_email_otp_match?, digest, "654321")
  end

  test "a digest issued for a different ceremony is refused for this one" do
    other_ceremony_digest = matcher(session_id: "step-up-2").invoke(:email_otp_digest, "123456")

    assert_not matcher(session_id: "step-up-1").invoke(:secure_email_otp_match?, other_ceremony_digest, "123456")
  end

  test "a ceremony that stored no digest matches nothing" do
    assert_not matcher.invoke(:secure_email_otp_match?, "", "123456")
  end
end
