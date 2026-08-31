# typed: false
# frozen_string_literal: true

require "test_helper"

# The app step-up base reads its scope and return target from whichever of
# several parameter sources carries them, and recovers an expired step-up session
# from those same values rather than dropping the person back to settings. The
# recovery arm and the parameter fallbacks had no coverage, so a step-up that
# stopped recovering would have looked identical to one that never expired.
class SignAppVerificationBaseFallbacksTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include ::SignAppVerificationBase

    attr_accessor :params, :session, :restore_raises, :started, :step_up_session, :cleared, :destroyed, :redirects

    def initialize
      @params = ActionController::Parameters.new(ri: "jp")
      @session = {}
      @started = []
      @cleared = 0
      @destroyed = 0
      @redirects = []
    end

    def invoke(name, ...) = send(name, ...)

    def start_step_up_session!(scope:, pt_param:)
      raise ActionController::BadRequest, "unusable step-up grant" if restore_raises

      started << [scope, pt_param]
    end

    def current_step_up_session = step_up_session

    def actor_token = Struct.new(:id).new(11)

    def clear_step_up_state! = self.cleared += 1

    def destroy_current_step_up_session! = self.destroyed += 1

    def email_otp_session_key = :sign_step_up_email_otp

    def step_up_session_storage_available? = true

    def safe_redirect_to(*args, **kwargs) = redirects << [args, kwargs]

    def auth_app_settings_path(**attrs) = "/settings?#{attrs.to_query}"

    def auth_app_root_path(**attrs) = "/?#{attrs.to_query}"
  end

  def live_session
    Struct.new(:discarded_at, :user_token_id, :status, :scope, :return_to)
      .new(1.minute.from_now, 11, "PENDING", "settings_email", "/settings/sessions")
  end

  test "a scope and return target are read from the verification scope or the bare parameters" do
    scoped = Harness.new
    scoped.params = ActionController::Parameters.new(verification: { scope: "settings_email", pt: "/a" })

    assert_equal "settings_email", scoped.invoke(:incoming_scope)
    assert_equal "/a", scoped.invoke(:incoming_pt)

    bare = Harness.new
    bare.params = ActionController::Parameters.new(scope: "settings_secret", pt: "/b")

    assert_equal "settings_secret", bare.invoke(:incoming_scope)
    assert_equal "/b", bare.invoke(:incoming_pt)
    assert_equal(
      { "scope" => "settings_secret", "pt" => "/b" },
      bare.invoke(:request_parameters).to_unsafe_h,
    )
  end

  test "an expired step-up session is restored from the parameters that carried it" do
    harness = Harness.new
    harness.params = ActionController::Parameters.new(
      ri: "jp", verification: { scope: "settings_email", pt: "/settings/sessions" },
    )
    harness.step_up_session = live_session

    assert harness.invoke(:handle_invalid_step_up_session!)
    assert_equal [["settings_email", "/settings/sessions"]], harness.started
    assert_empty harness.redirects
    assert_equal 1, harness.cleared
    assert_equal 1, harness.destroyed
  end

  test "a step-up that cannot be restored sends the person back to settings" do
    harness = Harness.new
    harness.params = ActionController::Parameters.new(
      ri: "jp", verification: { scope: "settings_email", pt: "/settings/sessions" },
    )
    harness.restore_raises = true

    assert_not harness.invoke(:handle_invalid_step_up_session!)
    assert_equal 1, harness.redirects.size
    assert_equal I18n.t("auth.step_up.session_expired"), harness.redirects.first.last.fetch(:alert)
  end

  test "restoring needs both a scope and a return target" do
    harness = Harness.new
    harness.params = ActionController::Parameters.new(verification: { scope: "settings_email" })

    assert_not harness.invoke(:restore_step_up_session_from_params!)
    assert_empty harness.started
  end

  test "clearing the email OTP session answers nothing so the caller re-issues" do
    harness = Harness.new

    assert_nil harness.invoke(:clear_and_return_nil_email_otp_session)
    assert_equal 1, harness.cleared
  end
end
